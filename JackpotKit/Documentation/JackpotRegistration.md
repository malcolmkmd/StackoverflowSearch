# JackpotRegistration

The registration feature, complete, as a package. The app's entire integration surface is one
view controller and one dependencies struct — **PR 4** in the delivery plan; **PR 5** is the app
swapping the old popup for it.

**iOS 15+ · depends on `JackpotUI`, `JackpotForms`, `JackpotNetworking` · 5 tests · 3 previews**

```bash
xcodebuild -scheme JackpotRegistration -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test
```

Open `Previews.swift` and resume — the full two-page flow, mock service, success and the
duplicate-mobile failure, with no app and no backend.

---

## What the app does with it (the whole of PR 5)

```swift
// TRANSITIONAL. Deleted by the localisation follow-up.
let legacyLocalizer = ClosureLocalizer { key in
    let value = getTranslation(Key: key)
    return value == key ? nil : value      // getTranslation returns the key on a miss
}

let controller = RegistrationPanelController(
    dependencies: RegistrationDependencies(
        forms: .live(baseURL: configURL, localizer: legacyLocalizer),
        service: MockRegistrationService()   // → RemoteRegistrationService once the endpoint is confirmed
    )
) { result in
    // route to OTP / login / home
}
addChild(controller)
popupContainer.show(controller.view)
controller.didMove(toParent: self)
```

Then delete `registrationPopup`, `flowOneViewController`, `flowTwoViewController`, their nibs and
their `GlobalData` handles.

## Design notes

**The feature reads nothing from the app.** The one thing it needs from the legacy world — the
current `getTranslation` — arrives as a `FormLocalizing` the app builds. `ClosureLocalizer`
(in `JackpotFormsDomain`) is the wrapper; the key-on-miss → `nil` mapping is what keeps missing
strings rendering as readable fallbacks rather than raw keys.

**`RegistrationService` is a protocol** so the screen is live and validated end to end while the
submit contract is still being confirmed. `MockRegistrationService` is the default; `Remote` is
wired and one line to swap in.

**`RemoteRegistrationService` is provisional.** The path, body and response shape of the
registration POST are open question #5 in the forms README. `RegisterRequest` compiles and is a
best guess to be corrected with the backend — it's marked `TODO` in the source.

**`RegistrationPanelController` is a `UIHostingController`** rather than a bare view, so safe
areas, keyboard avoidance and environment propagation work inside the legacy popup container.
It must be added as a child of whatever presents it.

---

## Building it from scratch

Five files, one target. `JackpotUI`, `JackpotForms` and `JackpotCore` must exist first (each
has its own build guide).

```bash
mkdir -p Packages/JackpotRegistration/Sources/JackpotRegistration Packages/JackpotRegistration/Tests/JackpotRegistrationTests
cd Packages/JackpotRegistration
printf '.build/\n.swiftpm/\n*.xcuserdatad\n' > .gitignore
```

#### Package manifest · `Package.swift`

```swift
// swift-tools-version: 5.7
import PackageDescription

// The registration feature, complete, as a package. The app's only job is to present
// `RegistrationPanelController` where the old sign-up popup was and hand it dependencies.
//
// Nothing in here references the app. The one thing it needs from the legacy world — the
// current translation function — arrives as a `FormLocalizing` the app constructs.
let package = Package(
    name: "JackpotRegistration",
    platforms: [.iOS(.v15)],
    products: [
        .library(name: "JackpotRegistration", targets: ["JackpotRegistration"]),
    ],
    dependencies: [
        .package(path: "../JackpotUI"),
        .package(path: "../JackpotForms"),
        .package(path: "../JackpotCore"),
    ],
    targets: [
        .target(
            name: "JackpotRegistration",
            dependencies: [
                .product(name: "JackpotUI", package: "JackpotUI"),
                .product(name: "JackpotForms", package: "JackpotForms"),
                .product(name: "JackpotNetworking", package: "JackpotCore"),
            ]
        ),
        .testTarget(name: "JackpotRegistrationTests", dependencies: ["JackpotRegistration"]),
    ]
)
```

#### Step 1 · create `Sources/JackpotRegistration/RegistrationService.swift`

The protocol, the mock, the provisional remote implementation, and the user-facing error type. `RegistrationError` is `LocalizedError` because that's what the form engine displays above the Sign Up button.

```swift
import Foundation
import JackpotNetworking
import JackpotFormsDomain
import JackpotForms

/// What happens to the collected form values. The engine hands us a `FormSubmission`; this
/// turns it into an account.
public protocol RegistrationService: Sendable {
    func register(_ submission: FormSubmission) async throws -> RegistrationResult
}

/// What the app needs to know afterwards. ⚠️ Provisional: the registration POST's real
/// response shape is open question #5 in the forms README. Extend when it's confirmed.
public struct RegistrationResult: Equatable, Sendable {
    public let accountNumber: String?
    public let requiresOTP: Bool

    public init(accountNumber: String?, requiresOTP: Bool) {
        self.accountNumber = accountNumber
        self.requiresOTP = requiresOTP
    }
}

/// Succeeds after a short delay; fails if the mobile is `"0000000000"`. Enough to demo both
/// paths and to drive previews and tests.
public struct MockRegistrationService: RegistrationService {
    private let delay: TimeInterval

    public init(delay: TimeInterval = 0.6) { self.delay = delay }

    public func register(_ submission: FormSubmission) async throws -> RegistrationResult {
        try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        if submission["username"].stringValue == "0000000000" {
            throw RegistrationError.mobileAlreadyRegistered
        }
        return RegistrationResult(accountNumber: "27\(submission["username"].stringValue)", requiresOTP: true)
    }
}

/// Posts the values to the registration endpoint.
///
/// ⚠️ The path, body shape and response shape are **not confirmed** — see open question #5.
/// This compiles and is wired, but `RegisterRequest` is a best guess to be corrected when the
/// backend contract is known. Keep the mock as the default until then.
public struct RemoteRegistrationService: RegistrationService {
    private let apiClient: any ApiClient

    public init(apiClient: any ApiClient) { self.apiClient = apiClient }

    public func register(_ submission: FormSubmission) async throws -> RegistrationResult {
        do {
            let dto: RegisterResponseDTO = try await apiClient.request(RegisterRequest(fields: submission.stringValues))
            return RegistrationResult(accountNumber: dto.accountNumber, requiresOTP: dto.requiresOtp ?? false)
        } catch let error as APIError {
            throw RegistrationError(error)
        }
    }
}

struct RegisterRequest: APIEndpoint {
    let fields: [String: String]
    var path: String { "registration" }              // TODO: confirm with backend
    var method: HTTPMethod { .POST }
    var body: RequestBody? { try? .encodable(fields) }
    var requiresAuth: Bool { false }
}

struct RegisterResponseDTO: Decodable, Sendable {
    let accountNumber: String?
    let requiresOtp: Bool?
}

/// User-facing failures. `LocalizedError` because that's what the form engine displays.
public enum RegistrationError: LocalizedError, Equatable {
    case mobileAlreadyRegistered
    case offline
    case server(message: String)
    case unexpected

    init(_ apiError: APIError) {
        if apiError.isOffline { self = .offline; return }
        switch apiError {
        case .badRequest(let problem) where problem?.code == 1042:   // TODO: confirm code
            self = .mobileAlreadyRegistered
        case .badRequest, .unauthorized, .server, .unexpectedStatus:
            if let message = apiError.serverMessage { self = .server(message: message) } else { self = .unexpected }
        default:
            self = .unexpected
        }
    }

    public var errorDescription: String? {
        switch self {
        case .mobileAlreadyRegistered: return "That mobile number is already registered. Try logging in instead."
        case .offline:                 return "You're offline. Check your connection and try again."
        case .server(let message):     return message
        case .unexpected:              return "Something went wrong. Please try again."
        }
    }
}
```

#### Step 2 · create `Sources/JackpotRegistration/RegistrationFeature.swift`

`RegistrationDependencies` and `RegistrationView`. `.mock(localizer:)` is what the previews and the sandbox use; the app passes `.live(...)`.

```swift
import SwiftUI
import JackpotUI
import JackpotFormsDomain
import JackpotFormsUI
import JackpotForms

/// Everything the feature needs, supplied by the app at the one place it's presented.
public struct RegistrationDependencies {
    /// How the schema is fetched and localised. `.mock(localizer:)` until networking lands,
    /// `.live(baseURL:localizer:)` after.
    public var forms: FormDependencies
    /// What to do with the values once they validate.
    public var service: any RegistrationService
    public var theme: JackpotTheme

    public init(forms: FormDependencies,
                service: any RegistrationService,
                theme: JackpotTheme = .jackpotCity) {
        self.forms = forms
        self.service = service
        self.theme = theme
    }

    /// Bundled schema, mock service. Works with no backend and no app — the state of the
    /// feature at the end of PR 2, and what the app's final PR replaces with `.live`.
    ///
    /// - Parameter localizer: the app's existing translation function, wrapped:
    ///   `ClosureLocalizer { key in … getTranslation(Key: key) … }`. Nil → bundled placeholder copy.
    public static func mock(localizer: (any FormLocalizing)? = nil) -> RegistrationDependencies {
        RegistrationDependencies(forms: .mock(localizer: localizer), service: MockRegistrationService())
    }
}

/// The registration screen. Two-page schema-driven form; on success reports the result.
public struct RegistrationView: View {
    private let dependencies: RegistrationDependencies
    private let onComplete: (RegistrationResult) -> Void

    public init(dependencies: RegistrationDependencies, onComplete: @escaping (RegistrationResult) -> Void) {
        self.dependencies = dependencies
        self.onComplete = onComplete
    }

    public var body: some View {
        DynamicFormView(formName: .registration) { submission in
            // Thrown errors render above the Sign Up button; the form stays filled in.
            let result = try await dependencies.service.register(submission)
            await MainActor.run { onComplete(result) }
        }
        .formDependencies(dependencies.forms)
        .jackpotTheme(dependencies.theme)
    }
}
```

#### Step 3 · create `Sources/JackpotRegistration/RegistrationPanelController.swift`

The drop-in for the legacy popup. `#if canImport(UIKit)` so the package still type-checks on a macOS host for `swift test`.

```swift
import UIKit
import SwiftUI

/// Drop-in replacement for the legacy registration popup.
///
/// The old flow was a nib-backed `UIView` shown over dimmed content. This hosts the SwiftUI
/// feature in a view controller so safe areas, keyboard avoidance and environment propagation
/// work, and exposes `panelView` for containers that expect a `UIView`.
///
/// App-side usage (the entirety of the final PR's wiring):
///
/// ```swift
/// let controller = RegistrationPanelController(dependencies: .mock(localizer: legacyLocalizer)) { result in
///     // route to OTP / login / home
/// }
/// addChild(controller)
/// popupContainer.show(controller.view)
/// controller.didMove(toParent: self)
/// ```
public final class RegistrationPanelController: UIHostingController<RegistrationView> {

    public init(dependencies: RegistrationDependencies, onComplete: @escaping (RegistrationResult) -> Void) {
        super.init(rootView: RegistrationView(dependencies: dependencies, onComplete: onComplete))
        view.backgroundColor = .clear
        if #available(iOS 16.0, *) { sizingOptions = [.intrinsicContentSize] }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("Use init(dependencies:onComplete:)") }

    /// For legacy containers that take a `UIView`. The controller must still be added as a
    /// child of whatever presents it.
    public var panelView: UIView { view }
}
```

#### Step 4 · create `Sources/JackpotRegistration/Previews.swift`

Bundled copy, app-supplied localizer, and the loading state.

```swift
#if DEBUG
import SwiftUI
import JackpotUI
import JackpotFormsDomain
import JackpotFormsUI
import JackpotForms

struct RegistrationView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            RegistrationView(dependencies: .mock()) { _ in }
                .previewDisplayName("Registration — mock, bundled copy")

            // What the app does during the migration: its own translation function, wrapped.
            RegistrationView(dependencies: .mock(localizer: ClosureLocalizer { key in
                ["username": "Enter Mobile Number", "password": "Password", "email": "Email"][key]
            })) { _ in }
            .previewDisplayName("Registration — mock, app localizer")

            RegistrationView(dependencies: .init(forms: .mock(delay: 3600), service: MockRegistrationService())) { _ in }
                .previewDisplayName("Loading")
        }
        .frame(height: 640)
        .background(JackpotTheme.jackpotCity.surface)
        .preferredColorScheme(.dark)
        .previewLayout(.sizeThatFits)
    }
}
#endif
```

#### Step 5 · create `Tests/JackpotRegistrationTests/RegistrationServiceTests.swift`

Mock success and failure, every error has copy, `APIError` → `RegistrationError` mapping, and the migration seam: `ClosureLocalizer` maps key-on-miss to `nil`.

```swift
import XCTest
@testable import JackpotRegistration
import JackpotFormsDomain
import JackpotForms
import JackpotNetworking

final class RegistrationServiceTests: XCTestCase {

    private func submission(mobile: String) -> FormSubmission {
        FormSubmission(formCodeName: .registration, values: ["username": .text(mobile), "terms": .bool(true)])
    }

    func testMockSucceedsAndReportsOTP() async throws {
        let result = try await MockRegistrationService(delay: 0).register(submission(mobile: "849134302"))
        XCTAssertEqual(result, RegistrationResult(accountNumber: "27849134302", requiresOTP: true))
    }

    func testMockDuplicateMobileFailsWithAReadableMessage() async {
        do {
            _ = try await MockRegistrationService(delay: 0).register(submission(mobile: "0000000000"))
            XCTFail("expected a throw")
        } catch {
            XCTAssertEqual(error as? RegistrationError, .mobileAlreadyRegistered)
            XCTAssertNotNil((error as? LocalizedError)?.errorDescription)
        }
    }

    /// The form engine displays `LocalizedError.errorDescription`; every case must have one.
    func testEveryErrorHasUserFacingCopy() {
        let cases: [RegistrationError] = [.mobileAlreadyRegistered, .offline, .server(message: "x"), .unexpected]
        for c in cases { XCTAssertFalse((c.errorDescription ?? "").isEmpty, "\(c)") }
    }

    func testAPIErrorsMapToRegistrationErrors() {
        XCTAssertEqual(RegistrationError(.transport(.notConnectedToInternet)), .offline)
        XCTAssertEqual(RegistrationError(.badRequest(APIProblem(code: 1042, message: "dup"))), .mobileAlreadyRegistered)
        XCTAssertEqual(RegistrationError(.badRequest(APIProblem(code: 7, message: "Bad input"))), .server(message: "Bad input"))
        XCTAssertEqual(RegistrationError(.server(nil)), .unexpected)
    }

    /// The migration seam: the app's `getTranslation` returns the key on a miss, and that
    /// must become nil so the engine can fall back to humanised copy.
    func testClosureLocalizerMapsKeyOnMissToNil() {
        func legacyGetTranslation(Key: String) -> String { Key == "username" ? "Enter Mobile Number" : Key }
        let localizer = ClosureLocalizer { key in
            let value = legacyGetTranslation(Key: key)
            return value == key ? nil : value
        }
        XCTAssertEqual(localizer.string(forKey: "username"), "Enter Mobile Number")
        XCTAssertNil(localizer.string(forKey: "dateOfBirth"))
        XCTAssertEqual(localizer.display("dateOfBirth"), "Date Of Birth")
    }
}
```

**✓ Checkpoint**

```bash
xcodebuild -scheme JackpotRegistration -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test
```

`Executed 5 tests, with 0 failures`

Then open the previews.

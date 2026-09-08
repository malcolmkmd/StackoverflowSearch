// swift-tools-version: 5.10
import PackageDescription

// One local package; each folder under Sources/ is a module.
//
// In Xcode: File → Add Package Dependencies → Add Local… → JackpotKit, then add the product you
// need to the app target. `JackpotRegistration` is the registration feature, `JackpotForms` the
// schema-driven engine it runs on, `JackpotUI` the design system.
//
// `JackpotAppData` and the store half of `JackpotLocalization` are the app-data follow-up
// (docs/adr/0001); registration does not depend on either.
//
// The floor is iOS 15, the host app's. That is why the models are `ObservableObject` and why
// a few views carry an `#available(iOS 16.0, *)` branch.

/// The app builds with `SWIFT_STRICT_CONCURRENCY = complete`; the package is held to the same bar.
let strict: [SwiftSetting] = [.enableExperimentalFeature("StrictConcurrency")]

let package = Package(
    name: "JackpotKit",
    defaultLocalization: "en",
    platforms: [.iOS(.v15)],
    products: [
        .library(
            name: "JackpotKit",
            targets: ["JackpotUI", "JackpotNetworking", "JackpotLocalization", "JackpotAppData",
                      "JackpotForms", "JackpotRegistration"]
        ),
        .library(name: "JackpotUI", targets: ["JackpotUI"]),
        .library(name: "JackpotNetworking", targets: ["JackpotNetworking"]),
        .library(name: "JackpotLocalization", targets: ["JackpotLocalization"]),
        .library(name: "JackpotAppData", targets: ["JackpotAppData"]),
        .library(name: "JackpotForms", targets: ["JackpotForms"]),
        .library(name: "JackpotRegistration", targets: ["JackpotRegistration"]),
    ],
    targets: [
        .target(name: "JackpotUI", swiftSettings: strict),
        .testTarget(name: "JackpotUITests", dependencies: ["JackpotUI"]),

        .target(name: "JackpotNetworking", swiftSettings: strict),
        .testTarget(name: "JackpotNetworkingTests", dependencies: ["JackpotNetworking"]),

        .target(name: "JackpotLocalization", swiftSettings: strict),
        .testTarget(name: "JackpotLocalizationTests", dependencies: ["JackpotLocalization"]),

        .target(
            name: "JackpotAppData",
            dependencies: ["JackpotNetworking", "JackpotLocalization"],
            swiftSettings: strict
        ),
        .testTarget(name: "JackpotAppDataTests", dependencies: ["JackpotAppData", "JackpotNetworking"]),

        .target(
            name: "JackpotForms",
            dependencies: ["JackpotUI", "JackpotNetworking", "JackpotLocalization"],
            resources: [.process("Resources")],
            swiftSettings: strict
        ),
        .testTarget(
            name: "JackpotFormsTests",
            dependencies: ["JackpotForms", "JackpotNetworking", "JackpotLocalization"]
        ),

        .target(name: "JackpotRegistration", dependencies: ["JackpotUI", "JackpotForms"], swiftSettings: strict),
        .testTarget(name: "JackpotRegistrationTests", dependencies: ["JackpotRegistration", "JackpotForms"]),
    ]
)

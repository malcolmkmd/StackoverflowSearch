// swift-tools-version: 5.10
import PackageDescription

// One local package; each folder under Sources/ is a module. In Xcode: File → Add Package
// Dependencies → Add Local… → JackpotKit, then add the product you need to the app target.
// The floor is iOS 15, the host app's. docs/BUILD-PLAYBOOK.md builds this manifest one step at a
// time, and scripts/build-playbook.py checks that its final step matches this file exactly.

/// The app builds with `SWIFT_STRICT_CONCURRENCY = complete`; the package is held to the same bar.
let strict: [SwiftSetting] = [.enableExperimentalFeature("StrictConcurrency")]

let package = Package(
    name: "JackpotKit",
    defaultLocalization: "en",
    platforms: [.iOS(.v15)],
    products: [
        .library(
            name: "JackpotKit",
            targets: ["JackpotUI", "JackpotForms", "JackpotRegistration",
                      "JackpotNetworking", "JackpotLocalization", "JackpotAppData"]
        ),
        .library(name: "JackpotUI", targets: ["JackpotUI"]),
        .library(name: "JackpotForms", targets: ["JackpotForms"]),
        .library(name: "JackpotRegistration", targets: ["JackpotRegistration"]),
        .library(name: "JackpotNetworking", targets: ["JackpotNetworking"]),
        .library(name: "JackpotLocalization", targets: ["JackpotLocalization"]),
        .library(name: "JackpotAppData", targets: ["JackpotAppData"]),
    ],
    targets: [
        .target(name: "JackpotUI", swiftSettings: strict),
        .testTarget(name: "JackpotUITests", dependencies: ["JackpotUI"]),

        .target(
            name: "JackpotForms",
            dependencies: ["JackpotUI", "JackpotNetworking"],
            resources: [.process("Resources")],
            swiftSettings: strict
        ),
        .testTarget(name: "JackpotFormsTests", dependencies: ["JackpotForms", "JackpotNetworking"]),
        .target(name: "JackpotRegistration", dependencies: ["JackpotUI", "JackpotForms"], swiftSettings: strict),
        .testTarget(name: "JackpotRegistrationTests", dependencies: ["JackpotRegistration", "JackpotForms"]),

        .target(name: "JackpotNetworking", swiftSettings: strict),
        .testTarget(name: "JackpotNetworkingTests", dependencies: ["JackpotNetworking"]),

        .target(name: "JackpotLocalization", swiftSettings: strict),
        .testTarget(name: "JackpotLocalizationTests", dependencies: ["JackpotLocalization"]),

        .target(name: "JackpotAppData", dependencies: ["JackpotNetworking", "JackpotLocalization"], swiftSettings: strict),
        .testTarget(name: "JackpotAppDataTests", dependencies: ["JackpotAppData", "JackpotNetworking"]),
    ]
)

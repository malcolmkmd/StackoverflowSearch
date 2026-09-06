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

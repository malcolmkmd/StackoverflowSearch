// swift-tools-version: 5.7
import PackageDescription

// Single local package the app depends on. Each folder under Sources/ is a Swift module.
// Add a new module by creating Sources/<Name> and listing it in products + targets below.
//
// In Xcode: File → Add Package Dependencies → Add Local… → JackpotKit
// Then add the JackpotKit product to the app target. Import the module you need
// (`import JackpotUI`, `import JackpotRegistration`, …).
let package = Package(
    name: "JackpotKit",
    defaultLocalization: "en",
    platforms: [.iOS(.v15)],
    products: [
        .library(
            name: "JackpotKit",
            targets: [
                "JackpotUI",
                "JackpotNetworking",
                "JackpotAppData",
                "JackpotLocalization",
                "JackpotFormsDomain",
                "JackpotFormsData",
                "JackpotFormsUI",
                "JackpotFormsRemote",
                "JackpotForms",
                "JackpotRegistration",
            ]
        ),
        .library(name: "JackpotUI", targets: ["JackpotUI"]),
        .library(name: "JackpotNetworking", targets: ["JackpotNetworking"]),
        .library(name: "JackpotAppData", targets: ["JackpotAppData"]),
        .library(name: "JackpotLocalization", targets: ["JackpotLocalization"]),
        .library(
            name: "JackpotForms",
            targets: [
                "JackpotForms",
                "JackpotFormsDomain",
                "JackpotFormsData",
                "JackpotFormsUI",
                "JackpotFormsRemote",
            ]
        ),
        .library(name: "JackpotRegistration", targets: ["JackpotRegistration"]),
    ],
    targets: [
        .target(name: "JackpotUI"),
        .testTarget(name: "JackpotUITests", dependencies: ["JackpotUI"]),

        .target(name: "JackpotNetworking"),
        .target(name: "JackpotAppData", dependencies: ["JackpotNetworking"]),
        .target(name: "JackpotLocalization", dependencies: ["JackpotNetworking", "JackpotAppData"]),
        .testTarget(name: "JackpotNetworkingTests", dependencies: ["JackpotNetworking"]),
        .testTarget(name: "JackpotAppDataTests", dependencies: ["JackpotAppData", "JackpotNetworking"]),
        .testTarget(name: "JackpotLocalizationTests", dependencies: ["JackpotLocalization"]),

        .target(name: "JackpotFormsDomain"),
        .target(name: "JackpotFormsData", dependencies: ["JackpotFormsDomain"]),
        .target(
            name: "JackpotFormsUI",
            dependencies: ["JackpotFormsDomain", "JackpotUI"],
            resources: [.process("Resources")]
        ),
        .target(
            name: "JackpotFormsRemote",
            dependencies: ["JackpotFormsDomain", "JackpotFormsData", "JackpotNetworking"]
        ),
        .target(
            name: "JackpotForms",
            dependencies: [
                "JackpotFormsDomain",
                "JackpotFormsData",
                "JackpotFormsUI",
                "JackpotFormsRemote",
                "JackpotLocalization",
                "JackpotNetworking",
            ]
        ),
        .testTarget(
            name: "JackpotFormsTests",
            dependencies: [
                "JackpotFormsDomain",
                "JackpotFormsData",
                "JackpotFormsUI",
                "JackpotFormsRemote",
                "JackpotForms",
                "JackpotNetworking",
                "JackpotLocalization",
            ],
            resources: [.process("Fixtures")]
        ),

        .target(
            name: "JackpotRegistration",
            dependencies: [
                "JackpotUI",
                "JackpotForms",
                "JackpotFormsDomain",
                "JackpotFormsUI",
                "JackpotNetworking",
            ]
        ),
        .testTarget(
            name: "JackpotRegistrationTests",
            dependencies: [
                "JackpotRegistration",
                "JackpotFormsDomain",
                "JackpotForms",
                "JackpotNetworking",
            ]
        ),
    ]
)

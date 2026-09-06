// swift-tools-version: 5.7
import PackageDescription

// Shared infrastructure for the JackpotCity app. Nothing here knows about any one
// feature — forms, account, casino and payments all sit on top of it.
//
// `JackpotNetworking`, `JackpotAppData` and `JackpotLocalization` today. `JackpotSecurity` (keychain, biometrics) and
// `JackpotDiagnostics` (leak detection, memory reporting) belong here next; see task 13 of
// the modernization plan.
let package = Package(
    name: "JackpotCore",
    platforms: [.iOS(.v15)],
    products: [
        .library(name: "JackpotNetworking", targets: ["JackpotNetworking"]),
        .library(name: "JackpotAppData", targets: ["JackpotAppData"]),
        .library(name: "JackpotLocalization", targets: ["JackpotLocalization"]),
    ],
    targets: [
        .target(name: "JackpotNetworking"),
        // Bootstrap-payload ingestion. Every feature reads its own section from this.
        .target(name: "JackpotAppData", dependencies: ["JackpotNetworking"]),
        .target(name: "JackpotLocalization", dependencies: ["JackpotNetworking", "JackpotAppData"]),

        .testTarget(name: "JackpotNetworkingTests", dependencies: ["JackpotNetworking"]),
        .testTarget(name: "JackpotAppDataTests", dependencies: ["JackpotAppData"]),
        .testTarget(name: "JackpotLocalizationTests", dependencies: ["JackpotLocalization"]),
    ]
)

// swift-tools-version: 5.7
import PackageDescription

// The design system. Components and tokens only — no data, no networking, no feature logic.
// Everything in here is driven by bindings and plain values, so it can be previewed and reused
// by any feature without knowing what the feature is.
let package = Package(
    name: "JackpotUI",
    platforms: [.iOS(.v15)],
    products: [
        .library(name: "JackpotUI", targets: ["JackpotUI"]),
    ],
    targets: [
        .target(name: "JackpotUI"),
        .testTarget(name: "JackpotUITests", dependencies: ["JackpotUI"]),
    ]
)

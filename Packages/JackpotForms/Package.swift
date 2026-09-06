// swift-tools-version: 5.7
import PackageDescription

// Renders CRM-authored JSON form schemas as native SwiftUI, on top of the JackpotUI design
// system. The mock repository has no networking dependency; the live one lives in its own
// target so the forms package can ship and be reviewed before the networking package exists.
let package = Package(
    name: "JackpotForms",
    defaultLocalization: "en",
    platforms: [.iOS(.v15)],
    products: [
        // One product, every target: consumers add this and import the modules they use.
        .library(
            name: "JackpotForms",
            targets: ["JackpotForms", "JackpotFormsDomain", "JackpotFormsData", "JackpotFormsUI", "JackpotFormsRemote"]
        ),
    ],
    dependencies: [
        .package(path: "../JackpotUI"),
        .package(path: "../JackpotCore"),
    ],
    targets: [
        // Entities + rules. Foundation only — no networking, no SwiftUI.
        .target(name: "JackpotFormsDomain"),

        // DTOs, mapper, and the bundled-JSON stub repository. No networking. (PR 2)
        .target(name: "JackpotFormsData", dependencies: ["JackpotFormsDomain"]),

        // SwiftUI rendering over the design system. Depends on Domain only — never on Data.
        .target(
            name: "JackpotFormsUI",
            dependencies: [
                "JackpotFormsDomain",
                .product(name: "JackpotUI", package: "JackpotUI"),
            ],
            resources: [.process("Resources")]
        ),

        // The live repository, endpoints and error mapping. The only forms target that
        // touches networking. (PR 4)
        .target(
            name: "JackpotFormsRemote",
            dependencies: [
                "JackpotFormsDomain",
                "JackpotFormsData",
                .product(name: "JackpotNetworking", package: "JackpotCore"),
            ]
        ),

        // Composition: `.mock()` and `.live()`. The only target that sees everything.
        .target(
            name: "JackpotForms",
            dependencies: [
                "JackpotFormsData",
                "JackpotFormsUI",
                "JackpotFormsRemote",
                .product(name: "JackpotLocalization", package: "JackpotCore"),
            ]
        ),

        .testTarget(
            name: "JackpotFormsTests",
            dependencies: ["JackpotFormsDomain", "JackpotFormsData", "JackpotFormsUI",
                           "JackpotFormsRemote", "JackpotForms"],
            resources: [.process("Fixtures")]
        ),
    ]
)

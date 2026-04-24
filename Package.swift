// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AeroMux",
    platforms: [
        .macOS(.v13),
    ],
    products: [
        .executable(name: "AeroMux", targets: ["AeroMux"]),
    ],
    dependencies: [
        .package(url: "https://github.com/sindresorhus/KeyboardShortcuts", from: "2.2.0"),
    ],
    targets: [
        .executableTarget(
            name: "AeroMux",
            dependencies: [
                .product(name: "KeyboardShortcuts", package: "KeyboardShortcuts"),
            ],
            path: "Sources",
            exclude: [
                "Resources",
            ]
        ),
    ]
)

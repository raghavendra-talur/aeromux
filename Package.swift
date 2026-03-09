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
    targets: [
        .executableTarget(
            name: "AeroMux",
            path: "Sources"
        ),
    ]
)

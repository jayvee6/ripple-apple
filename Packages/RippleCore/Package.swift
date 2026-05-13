// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "RippleCore",
    platforms: [
        .iOS(.v17),
        .watchOS(.v10),
        .macOS(.v14),
    ],
    products: [
        .library(name: "RippleCore", targets: ["RippleCore"]),
    ],
    targets: [
        .target(
            name: "RippleCore",
            path: "Sources/RippleCore"
        ),
        .testTarget(
            name: "RippleCoreTests",
            dependencies: ["RippleCore"],
            path: "Tests/RippleCoreTests"
        ),
    ]
)

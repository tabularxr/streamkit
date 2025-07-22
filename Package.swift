// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "StreamKit",
    platforms: [
        .iOS(.v16),
        .visionOS(.v1)
    ],
    products: [
        .library(
            name: "StreamKit",
            targets: ["StreamKit"]),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "StreamKit",
            dependencies: [],
            path: "Sources"
        ),
        .testTarget(
            name: "StreamKitTests",
            dependencies: ["StreamKit"],
            path: "Tests"
        ),
    ]
)
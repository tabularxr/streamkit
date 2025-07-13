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
    dependencies: [
        .package(url: "https://github.com/daltoniam/Starscream.git", from: "4.0.6"),
        .package(url: "https://github.com/apple/swift-protobuf.git", from: "1.25.2")
    ],
    targets: [
        .target(
            name: "StreamKit",
            dependencies: [
                "Starscream",
                .product(name: "SwiftProtobuf", package: "swift-protobuf")
            ],
            path: "Sources"
        ),
        .testTarget(
            name: "StreamKitTests",
            dependencies: ["StreamKit"],
            path: "Tests"
        ),
    ]
)
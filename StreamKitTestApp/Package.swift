// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "StreamKitTestApp",
    platforms: [
        .iOS(.v18),
        .visionOS(.v2)
    ],
    products: [
        .executable(name: "StreamKitTestApp", targets: ["StreamKitTestApp"]),
    ],
    dependencies: [
        .package(path: "../StreamKit"),
    ],
    targets: [
        .executableTarget(
            name: "StreamKitTestApp",
            dependencies: ["StreamKit"],
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "StreamKitTestAppTests",
            dependencies: ["StreamKitTestApp", "StreamKit"]
        ),
    ]
)
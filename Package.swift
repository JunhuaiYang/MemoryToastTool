// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "MemoryToastTool",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "MemoryToastCore", targets: ["MemoryToastCore"])
    ],
    targets: [
        .target(
            name: "MemoryToastCore"
        ),
        .testTarget(
            name: "MemoryToastCoreTests",
            dependencies: ["MemoryToastCore"]
        )
    ]
)

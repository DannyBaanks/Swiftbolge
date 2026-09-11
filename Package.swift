// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "Swiftbolge",
    targets: [
        .target(
            name: "SwiftbolgeCore"
        ),
        .executableTarget(
            name: "swiftbolge",
            dependencies: ["SwiftbolgeCore"],
            path: "Sources/swiftbolge-cli"
        ),
        .testTarget(
            name: "SwiftbolgeTests",
            dependencies: ["SwiftbolgeCore"],
            resources: [.copy("fixtures")]
        )
    ]
)

// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Shellmate",
    platforms: [
        .macOS(.v14)
    ],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.6.0"),
        .package(url: "https://github.com/scinfu/SwiftSoup", from: "2.7.0"),
    ],
    targets: [
        .executableTarget(
            name: "Shellmate",
            dependencies: [
                "Sparkle",
                "SwiftSoup",
            ],
            path: "Shellmate",
            resources: [
                .process("Resources"),
            ]
        ),
        .testTarget(
            name: "ShellmateTests",
            dependencies: ["Shellmate"],
            path: "ShellmateTests"
        ),
    ]
)

// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Shellmate",
    platforms: [
        .macOS(.v14)
    ],
    dependencies: [
        // Sparkle: macOS auto-update framework — pinned for security (signature verification)
        .package(url: "https://github.com/sparkle-project/Sparkle", exact: "2.9.0"),
        // SwiftSoup: HTML→text extraction for web_fetch tool
        .package(url: "https://github.com/scinfu/SwiftSoup", exact: "2.13.2"),
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

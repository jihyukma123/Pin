// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Pin",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "Pin", targets: ["Pin"]),
        .library(name: "PinCore", targets: ["PinCore"]),
    ],
    dependencies: [
        .package(url: "https://github.com/gonzalezreal/swift-markdown-ui", from: "2.4.0"),
    ],
    targets: [
        .executableTarget(
            name: "Pin",
            dependencies: [
                "PinCore",
                .product(name: "MarkdownUI", package: "swift-markdown-ui"),
            ],
            resources: [.copy("Resources/Icons")]
        ),
        .target(name: "PinCore"),
        .testTarget(
            name: "PinCoreTests",
            dependencies: ["PinCore"],
            resources: [.copy("Fixtures")]
        ),
    ]
)

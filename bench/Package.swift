// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "bench",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(name: "BenchHarness", targets: ["BenchHarness"]),
        .executable(name: "BenchTool", targets: ["BenchTool"]),
    ],
    dependencies: [
        .package(path: "../../mamba-metal-swift"),
        .package(url: "https://github.com/huggingface/swift-transformers", from: "1.3.0"),
    ],
    targets: [
        .target(
            name: "BenchHarness",
            dependencies: [],
            path: "Sources/BenchHarness"
        ),
        .executableTarget(
            name: "BenchTool",
            dependencies: [
                "BenchHarness",
                .product(name: "MambaMetal", package: "mamba-metal-swift"),
                .product(name: "Tokenizers", package: "swift-transformers"),
            ],
            path: "Sources/BenchTool"
        )
    ]
)

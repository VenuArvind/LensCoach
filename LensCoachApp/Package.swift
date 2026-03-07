// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "LensCoachApp",
    platforms: [
        .iOS(.v16)
    ],
    products: [
        .library(
            name: "LensCoachApp",
            targets: ["LensCoachApp"]),
    ],
    dependencies: [
        // Dependencies removed due to resolution issues. Use mock tips in LLMTipGenerator.
    ],
    targets: [
        .target(
            name: "LensCoachApp",
            dependencies: [],
            path: "Sources",
            resources: [
                .copy("Resources/FrameScore.mlmodelc"),
                .copy("Resources/Phi-3-mini-4k-instruct-q4.gguf")
            ])
    ]
)

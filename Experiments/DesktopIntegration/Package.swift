// swift-tools-version: 5.9
import PackageDescription
let package = Package(name: "DesktopBlurPreview", platforms: [.macOS("15.2")], targets: [
    .target(name: "IntegrationCore"),
    .executableTarget(name:"PreferenceTests",dependencies:["IntegrationCore"],path:"PreferenceTests"),
    .target(name: "GeometryAnalysis", dependencies: ["IntegrationCore"]),
    .target(name: "NativeRendering", dependencies: ["IntegrationCore"]),
    .executableTarget(name: "RenderTests", dependencies: ["IntegrationCore", "NativeRendering"], path: "RenderTests"),
    .executableTarget(name: "GeometryTests", dependencies: ["GeometryAnalysis", "IntegrationCore"], path: "GeometryTests"),
    .target(name: "DesktopPipeline", dependencies: ["CaptureAdapter", "IntegrationCore", "GeometryAnalysis", "NativeRendering"]),
    .executableTarget(name: "IntegrationHarness", dependencies: ["DesktopPipeline", "CaptureAdapter", "IntegrationCore", "NativeRendering"], path: "IntegrationHarness"),
    .target(name: "PrivacyCore", path: "Inputs/PrivacyCore"),
    .target(name: "CaptureAdapter", dependencies: ["IntegrationCore", "PrivacyCore"]),
    .executableTarget(name: "DesktopBlurPreview", dependencies: ["IntegrationCore", "CaptureAdapter", "GeometryAnalysis", "NativeRendering", "DesktopPipeline"]),
    .executableTarget(name: "AdapterTests", dependencies: ["CaptureAdapter"], path: "AdapterTests"),
    .executableTarget(name: "IntegrationTests", dependencies: ["IntegrationCore"], path: "Tests")
])

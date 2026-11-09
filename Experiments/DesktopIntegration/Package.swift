// swift-tools-version: 5.9
import PackageDescription
let package = Package(name: "DesktopBlurPreview", platforms: [.macOS("15.2")], targets: [
    .target(name: "IntegrationCore"),
    .target(name: "GeometryAnalysis"),
    .executableTarget(name: "GeometryTests", dependencies: ["GeometryAnalysis"], path: "GeometryTests"),
    .target(name: "PrivacyCore", path: "Inputs/PrivacyCore"),
    .target(name: "CaptureAdapter", dependencies: ["IntegrationCore", "PrivacyCore"]),
    .executableTarget(name: "DesktopBlurPreview", dependencies: ["IntegrationCore", "CaptureAdapter"]),
    .executableTarget(name: "AdapterTests", dependencies: ["CaptureAdapter"], path: "AdapterTests"),
    .executableTarget(name: "IntegrationTests", dependencies: ["IntegrationCore"], path: "Tests")
])

// swift-tools-version: 5.9
import PackageDescription
let package = Package(name: "SelectiveBlurLab", platforms: [.macOS(.v13)], targets: [
    .target(name: "LabPolicy"),
    .target(name: "LabViews", dependencies: ["LabPolicy"]),
    .executableTarget(name: "LabViewTests", dependencies: ["LabViews"], path: "ViewTests"),
    .executableTarget(name: "LabPolicyTests", dependencies: ["LabPolicy"], path: "Tests"),
    .executableTarget(name: "SelectiveBlurLab", dependencies: ["LabPolicy", "LabViews"])
])

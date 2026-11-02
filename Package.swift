// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "HideWhatsApp",
    platforms: [.macOS(.v13)],
    targets: [
        .target(name: "PrivacyCore"),
        .executableTarget(name: "PrivacyCoreTests", dependencies: ["PrivacyCore"], path: "Tests/PrivacyCoreTests"),
        .executableTarget(name: "TargetIdentityTests", dependencies: ["PrivacyCore"], path: "Tests/TargetIdentityTests"),
        .executableTarget(
            name: "HideWhatsApp",
            dependencies: ["PrivacyCore"],
            path: "Sources/HideWhatsApp"
        )
    ]
)

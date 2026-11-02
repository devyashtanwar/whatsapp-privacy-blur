import Foundation
import CoreFoundation

public struct RuntimeSigningState {
    public let bundleIdentifier: String?
    public let signatureValid: Bool
    public let hardenedRuntime: Bool
    public let entitlements: [String: Any]
    public init(bundleIdentifier: String?, signatureValid: Bool, hardenedRuntime: Bool, entitlements: [String: Any]) {
        self.bundleIdentifier = bundleIdentifier; self.signatureValid = signatureValid
        self.hardenedRuntime = hardenedRuntime; self.entitlements = entitlements
    }
}

public struct CapabilityDocument: Codable, Equatable {
    public let schemaVersion: Int
    public let bundleIdentifier: String
    public let entitlements: [String: Bool]
    public let forbiddenCapabilities: [String]
    public let allowedResources: [String]
}

public enum CapabilityPolicy {
    public static let required = CapabilityDocument(
        schemaVersion: 1, bundleIdentifier: "devyashtanwar.whatsapp-privacy-cover",
        entitlements: ["com.apple.security.app-sandbox": true],
        forbiddenCapabilities: ["network", "microphone", "camera", "location", "personal-files",
            "contacts", "calendar", "photos", "bluetooth", "usb", "screen-capture",
            "accessibility", "keyboard", "clipboard", "secret-storage", "external-url-opening",
            "shell-execution", "persistent-settings"],
        allowedResources: ["capability-policy.json", "source-manifest.json"])

    public static func allows(_ state: RuntimeSigningState, policyData: Data?) -> Bool {
        guard state.signatureValid, state.hardenedRuntime,
              state.bundleIdentifier == required.bundleIdentifier,
              state.entitlements.count == 1,
              let sandbox = state.entitlements["com.apple.security.app-sandbox"] as? NSNumber,
              CFGetTypeID(sandbox) == CFBooleanGetTypeID(), sandbox.boolValue,
              let data = policyData,
              let document = try? JSONDecoder().decode(CapabilityDocument.self, from: data),
              document == required else { return false }
        return true
    }
}

import Foundation
import CoreFoundation
public enum PreviewPolicy {
    public static let bundleID = "devyashtanwar.whatsapp-blur-auto-beta"
    public static let forbidden = ["network", "microphone", "camera", "location", "personal-files", "contacts", "calendar", "photos", "bluetooth", "usb", "accessibility", "keyboard", "clipboard", "secret-storage", "external-url-opening", "shell-execution"]
    public static func allows(bundleID: String?, signatureValid: Bool, hardened: Bool, entitlements: [String: Any], data: Data?) -> Bool {
        guard bundleID == self.bundleID, signatureValid, hardened,
              entitlements.count == 1,
              let sandbox = entitlements["com.apple.security.app-sandbox"] as? NSNumber,
              CFGetTypeID(sandbox) == CFBooleanGetTypeID(), sandbox.boolValue,
              let data = data, let document = try? JSONDecoder().decode(Document.self, from: data),
              document == Document(schemaVersion: 2, bundleIdentifier: self.bundleID,
                  entitlements: ["com.apple.security.app-sandbox": true], forbiddenCapabilities: forbidden,
                  allowedResources: ["capability-policy.json", "source-manifest.json"],
                  captureScope: "automatic-independent-authenticated-whatsapp-windows",preferenceScope:"private-container-non-content-blur-preferences") else { return false }
        return true
    }
    private struct Document: Codable, Equatable {
        let schemaVersion: Int
        let bundleIdentifier: String
        let entitlements: [String: Bool]
        let forbiddenCapabilities: [String]
        let allowedResources: [String]
        let captureScope: String
        let preferenceScope: String
    }
}

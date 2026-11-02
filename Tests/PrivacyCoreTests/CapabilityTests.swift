import Foundation
import PrivacyCore

func capabilityTests() {
    let policy = try! Data(contentsOf: URL(fileURLWithPath: "Security/CapabilityPolicy.json"))
    let id = "devyashtanwar.whatsapp-privacy-cover"
    func state(_ entitlements: [String: Any] = ["com.apple.security.app-sandbox": true], valid: Bool = true, hardened: Bool = true, identifier: String? = "devyashtanwar.whatsapp-privacy-cover") -> RuntimeSigningState {
        .init(bundleIdentifier: identifier, signatureValid: valid, hardenedRuntime: hardened, entitlements: entitlements)
    }
    expect(CapabilityPolicy.allows(state(), policyData: policy))
    for extra in ["network.client", "network.server", "device.audio-input", "device.camera", "personal-information.location", "files.user-selected.read-write", "automation.apple-events", "application-groups", "temporary-exception.files.home-relative-path.read-only"] {
        expect(!CapabilityPolicy.allows(state(["com.apple.security.app-sandbox": true, "com.apple.security." + extra: true]), policyData: policy))
    }
    expect(!CapabilityPolicy.allows(state([:]), policyData: policy))
    expect(!CapabilityPolicy.allows(state(["com.apple.security.app-sandbox": false]), policyData: policy))
    expect(!CapabilityPolicy.allows(state(["com.apple.security.app-sandbox": 1]), policyData: policy))
    expect(!CapabilityPolicy.allows(state(valid: false), policyData: policy))
    expect(!CapabilityPolicy.allows(state(hardened: false), policyData: policy))
    expect(!CapabilityPolicy.allows(state(identifier: nil), policyData: policy))
    expect(!CapabilityPolicy.allows(state(identifier: id + ".impostor"), policyData: policy))
    expect(!CapabilityPolicy.allows(state(), policyData: nil))
    expect(!CapabilityPolicy.allows(state(), policyData: Data("{}".utf8)))
    let first = SessionSettings(); first.enabled = false; first.hoverReveal = true; first.width = 400
    let second = SessionSettings()
    expect(second.enabled && second.fullWindow && !second.hoverReveal && second.width == 308)
}

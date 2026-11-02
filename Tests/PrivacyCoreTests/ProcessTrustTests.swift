import Foundation
import PrivacyCore
func processTrustTests() {
    let registry = TrustedProcessRegistry()
    let authentic = ProcessCandidate(pid: 42, generation: 100, bundleIdentifier: "net.whatsapp.WhatsApp")
    let impostor = ProcessCandidate(pid: 43, generation: 100, bundleIdentifier: "net.whatsapp.WhatsApp")
    let unrelated = ProcessCandidate(pid: 44, generation: 100, bundleIdentifier: "other")
    let unknown = ProcessCandidate(pid: 45, generation: nil, bundleIdentifier: "net.whatsapp.WhatsApp")
    var validations = 0
    func validate(_ candidate: ProcessCandidate) -> Bool { validations += 1; return candidate.pid == 42 && candidate.generation == 100 }
    let allowed = registry.allowedPIDs([authentic, impostor, unrelated, unknown], validate: validate)
    expect(allowed == [42])
    expect(!allowed.contains(impostor.pid))
    expect(TrustedProcessRegistry.isTrustedForeground(42, allowed: allowed))
    expect(!TrustedProcessRegistry.isTrustedForeground(43, allowed: allowed))
    expect(!TrustedProcessRegistry.isTrustedForeground(nil, allowed: allowed))
    let oldCalls = validations
    expect(registry.allowedPIDs([authentic, impostor], validate: validate) == [42])
    expect(validations == oldCalls)
    let reused = ProcessCandidate(pid: 42, generation: 200, bundleIdentifier: "net.whatsapp.WhatsApp")
    expect(registry.allowedPIDs([reused], validate: validate).isEmpty)
    registry.invalidate()
    expect(registry.allowedPIDs([authentic], validate: { _ in false }).isEmpty)
    expect(!registry.allowedPIDs([authentic], validate: validate).contains(43))
}

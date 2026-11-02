import Foundation
import PrivacyCore
func processTrustTests() {
    let registry = TrustedProcessRegistry()
    let authentic = ProcessCandidate(pid: 42, generation: 100, bundleIdentifier: "net.whatsapp.WhatsApp")
    let impostor = ProcessCandidate(pid: 43, generation: 100, bundleIdentifier: "net.whatsapp.WhatsApp")
    let unrelated = ProcessCandidate(pid: 44, generation: 100, bundleIdentifier: "other")
    let unknown = ProcessCandidate(pid: 45, generation: nil, bundleIdentifier: "net.whatsapp.WhatsApp")
    var validations = 0
    func validate(_ candidate: ProcessCandidate) -> ProcessValidationResult {
        validations += 1
        return candidate.pid == 42 && candidate.generation == 100 ? .trusted : .failed(.init(stage: .validityCheck, status: -67050))
    }
    let allowed = registry.allowedPIDs([authentic, impostor, unrelated, unknown], validate: validate)
    expect(allowed == [42])
    expect(!allowed.contains(impostor.pid))
    expect(registry.failures[impostor.pid] == .init(stage: .validityCheck, status: -67050))
    expect(registry.failures[unknown.pid]?.stage == .invalidCandidate)
    expect(TrustedProcessRegistry.isTrustedForeground(42, allowed: allowed))
    expect(!TrustedProcessRegistry.isTrustedForeground(43, allowed: allowed))
    expect(!TrustedProcessRegistry.isTrustedForeground(nil, allowed: allowed))
    let oldCalls = validations
    expect(registry.allowedPIDs([authentic, impostor], validate: validate) == [42])
    expect(validations == oldCalls)
    let reused = ProcessCandidate(pid: 42, generation: 200, bundleIdentifier: "net.whatsapp.WhatsApp")
    expect(registry.allowedPIDs([reused], validate: validate).isEmpty)
    registry.invalidate()
    expect(registry.allowedPIDs([authentic], validate: { _ in .failed(.init(stage: .guestLookup, status: -60005)) }).isEmpty)
    expect(registry.failures[42]?.stage == .guestLookup)
    expect(!registry.allowedPIDs([authentic], validate: validate).contains(43))
    expect(registry.failures[42]?.stage == .guestLookup) // A retry is explicit, not implicit trust.
    registry.invalidate()
    expect(registry.failures.isEmpty)
    expect(registry.allowedPIDs([authentic], validate: validate) == [42])
    registry.invalidate()
    expect(registry.allowedPIDs([authentic], validate: { _ in .failed(.init(stage: .generationChanged)) }).isEmpty)
    expect(registry.failures[42]?.stage == .generationChanged)
    expect(registry.allowedPIDs([], validate: validate).isEmpty)
    expect(registry.failures.isEmpty)
    expect(ProcessIdentityFailure(stage: .guestLookup).summary != ProcessIdentityFailure(stage: .validityCheck).summary)
    expect(ProcessIdentityFailure(stage: .validityCheck).summary.contains("Cover inactive"))
}

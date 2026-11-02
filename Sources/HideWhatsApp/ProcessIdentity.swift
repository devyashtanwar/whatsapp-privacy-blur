import AppKit
import PrivacyCore

final class ProcessIdentityProvider {
    private let registry = TrustedProcessRegistry()
    private let validator = TargetCodeValidator()

    var failure: ProcessIdentityFailure? { registry.failures.sorted { $0.key < $1.key }.first?.value }
    func invalidate() { registry.invalidate() }

    static func candidate(_ app: NSRunningApplication) -> ProcessCandidate {
        .init(pid: app.processIdentifier, generation: app.launchDate?.timeIntervalSince1970,
              bundleIdentifier: app.bundleIdentifier)
    }

    func trustedPIDs(_ apps: [NSRunningApplication]) -> Set<Int32> {
        registry.allowedPIDs(apps.map(Self.candidate)) { candidate in
            let result = self.validator.validate(pid: candidate.pid)
            guard result == .trusted else { return result }
            guard let current = NSRunningApplication(processIdentifier: candidate.pid),
                  !current.isTerminated, Self.candidate(current) == candidate else {
                return .failed(.init(stage: .generationChanged))
            }
            return .trusted
        }
    }

    static func stillCurrent(_ original: NSRunningApplication) -> Bool {
        guard !original.isTerminated, let current = NSRunningApplication(processIdentifier: original.processIdentifier) else { return false }
        return candidate(current) == candidate(original)
    }
}

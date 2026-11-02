import AppKit
import Security
import PrivacyCore

final class ProcessIdentityProvider {
    private let registry = TrustedProcessRegistry()
    // Fixed publisher requirement. Matching an identifier or a TeamIdentifier
    // string alone is insufficient: the running code must satisfy Apple's anchor.
    private let requirement: SecRequirement?

    init() {
        var value: SecRequirement?
        let text = "anchor apple generic and identifier \"net.whatsapp.WhatsApp\" and certificate leaf[subject.OU] = \"57T9237FN3\""
        if SecRequirementCreateWithString(text as CFString, [], &value) == errSecSuccess { requirement = value }
        else { requirement = nil }
    }
    func invalidate() { registry.invalidate() }

    static func candidate(_ app: NSRunningApplication) -> ProcessCandidate {
        .init(pid: app.processIdentifier, generation: app.launchDate?.timeIntervalSince1970,
              bundleIdentifier: app.bundleIdentifier)
    }

    func trustedPIDs(_ apps: [NSRunningApplication]) -> Set<Int32> {
        registry.allowedPIDs(apps.map(Self.candidate)) { candidate in
            guard let requirement = self.requirement else { return false }
            var code: SecCode?
            let attributes = [kSecGuestAttributePid as String: NSNumber(value: candidate.pid)] as CFDictionary
            guard SecCodeCopyGuestWithAttributes(nil, attributes, [], &code) == errSecSuccess,
                  let code = code,
                  // Network-enabled trust evaluation is not requested. Missing offline
                  // certificate trust must reject the target, never fetch trust data.
                  SecCodeCheckValidity(code, SecCSFlags(rawValue: kSecCSStrictValidate | SecCSFlags.noNetworkAccess.rawValue), requirement) == errSecSuccess,
                  let current = NSRunningApplication(processIdentifier: candidate.pid),
                  !current.isTerminated, Self.candidate(current) == candidate else { return false }
            return true
        }
    }

    static func stillCurrent(_ original: NSRunningApplication) -> Bool {
        guard !original.isTerminated, let current = NSRunningApplication(processIdentifier: original.processIdentifier) else { return false }
        return candidate(current) == candidate(original)
    }
}

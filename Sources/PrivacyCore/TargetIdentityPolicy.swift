import Foundation
import Security

/// Fixed distribution identities; identifiers alone never establish trust.
public enum TargetIdentityPolicy {
    public static let developerIDRequirement = "anchor apple generic and identifier \"net.whatsapp.WhatsApp\" and certificate 1[field.1.2.840.113635.100.6.2.6] exists and certificate leaf[field.1.2.840.113635.100.6.1.13] exists and certificate leaf[subject.OU] = \"57T9237FN3\""
    public static let appStoreRequirement = "anchor apple generic and identifier \"net.whatsapp.WhatsApp\" and certificate leaf[field.1.2.840.113635.100.6.1.9] exists and entitlement[\"com.apple.developer.team-identifier\"] = \"57T9237FN3\" and entitlement[\"com.apple.application-identifier\"] = \"UKFA9XBX6K.net.whatsapp.WhatsApp\""
    public static let requirement = "(\(appStoreRequirement)) or (\(developerIDRequirement))"
}

public final class TargetCodeValidator {
    private let requirement: SecRequirement?
    public init() {
        var value: SecRequirement?
        if SecRequirementCreateWithString(TargetIdentityPolicy.requirement as CFString, [], &value) == errSecSuccess {
            requirement = value
        } else { requirement = nil }
    }
    public func validate(pid: Int32) -> ProcessValidationResult {
        guard let requirement = requirement else { return .failed(.init(stage: .requirementCreation)) }
        var code: SecCode?
        let attributes = [kSecGuestAttributePid as String: NSNumber(value: pid)] as CFDictionary
        let lookup = SecCodeCopyGuestWithAttributes(nil, attributes, [], &code)
        guard lookup == errSecSuccess, let code = code else { return .failed(.init(stage: .guestLookup, status: lookup)) }
        let status = SecCodeCheckValidity(code, SecCSFlags(rawValue: kSecCSStrictValidate | SecCSFlags.noNetworkAccess.rawValue), requirement)
        return status == errSecSuccess ? .trusted : .failed(.init(stage: .validityCheck, status: status))
    }
}

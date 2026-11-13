import Foundation
import Security
import IntegrationCore

/// Strict offline self-validation before constructing any UI or picker.
func confinementAllowed() -> Bool {
    var code: SecCode?
    guard SecCodeCopySelf([], &code) == errSecSuccess, let code = code,
          SecCodeCheckValidity(code, SecCSFlags(rawValue: kSecCSStrictValidate | SecCSFlags.noNetworkAccess.rawValue), nil) == errSecSuccess else { return false }
    var staticCode: SecStaticCode?
    var result: CFDictionary?
    guard SecCodeCopyStaticCode(code, [], &staticCode) == errSecSuccess, let staticCode = staticCode,
          SecStaticCodeCheckValidity(staticCode, SecCSFlags(rawValue: kSecCSStrictValidate | SecCSFlags.noNetworkAccess.rawValue), nil) == errSecSuccess,
          SecCodeCopySigningInformation(staticCode, SecCSFlags(rawValue: kSecCSSigningInformation), &result) == errSecSuccess,
          let info = result as? [String: Any],
          let entitlements = info[kSecCodeInfoEntitlementsDict as String] as? [String: Any],
          let flags = info[kSecCodeInfoFlags as String] as? NSNumber,
          let policyURL = Bundle.main.url(forResource: "capability-policy", withExtension: "json"),
          let policy = try? Data(contentsOf: policyURL),
          SecCodeCheckValidity(code, SecCSFlags(rawValue: kSecCSStrictValidate | SecCSFlags.noNetworkAccess.rawValue), nil) == errSecSuccess else { return false }
    return PreviewPolicy.allows(bundleID: Bundle.main.bundleIdentifier, signatureValid: true,
                               hardened: flags.uint32Value & 0x10000 != 0, entitlements: entitlements, data: policy)
}

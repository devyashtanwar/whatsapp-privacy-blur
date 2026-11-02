import Foundation
import Security
import Darwin
import PrivacyCore

// Real Security API checks, separate from the GUI app. Never launches a fixture.
func require(_ value: Bool, _ message: String) {
    if !value { fputs("FAIL: \(message)\n", stderr); exit(1) }
}
func requirement(_ text: String) -> SecRequirement {
    var result: SecRequirement?
    require(SecRequirementCreateWithString(text as CFString, [], &result) == errSecSuccess, "requirement must compile")
    return result!
}
let policy = requirement(TargetIdentityPolicy.requirement)
_ = requirement(TargetIdentityPolicy.appStoreRequirement)
_ = requirement(TargetIdentityPolicy.developerIDRequirement)
let arguments = CommandLine.arguments
if arguments.count == 4 && ["--fixture", "--store-fixture", "--developer-id-fixture"].contains(arguments[1]) {
    var code: SecStaticCode?
    require(SecStaticCodeCreateWithPath(URL(fileURLWithPath: arguments[2]) as CFURL, [], &code) == errSecSuccess, "fixture code lookup")
    let selected = arguments[1] == "--store-fixture" ? requirement(TargetIdentityPolicy.appStoreRequirement) :
        arguments[1] == "--developer-id-fixture" ? requirement(TargetIdentityPolicy.developerIDRequirement) : policy
    let status = SecStaticCodeCheckValidity(code!, SecCSFlags(rawValue: kSecCSStrictValidate | SecCSFlags.noNetworkAccess.rawValue), selected)
    require((status == errSecSuccess) == (arguments[3] == "accept"), "fixture outcome \(status)")
    if arguments[3] == "accept" {
        let original = arguments[1] == "--store-fixture" ? TargetIdentityPolicy.appStoreRequirement :
            arguments[1] == "--developer-id-fixture" ? TargetIdentityPolicy.developerIDRequirement : TargetIdentityPolicy.requirement
        let wrongTeam = requirement(original.replacingOccurrences(of: "57T9237FN3", with: "WRONGTEAM"))
        require(SecStaticCodeCheckValidity(code!, SecCSFlags(rawValue: kSecCSStrictValidate | SecCSFlags.noNetworkAccess.rawValue), wrongTeam) != errSecSuccess, "wrong publisher must fail even with a valid Apple signature")
        if arguments[1] == "--store-fixture" {
            let wrongApp = requirement(original.replacingOccurrences(of: "UKFA9XBX6K.net.whatsapp.WhatsApp", with: "OTHER.net.whatsapp.WhatsApp"))
            require(SecStaticCodeCheckValidity(code!, SecCSFlags(rawValue: kSecCSStrictValidate | SecCSFlags.noNetworkAccess.rawValue), wrongApp) != errSecSuccess, "wrong signed application identity must fail")
        }
    }
    print("Security fixture check passed")
} else if arguments.count == 3 && arguments[1] == "--pid", let pid = Int32(arguments[2]) {
    let result = TargetCodeValidator().validate(pid: pid)
    require(result == .trusted, "live process check: \(result)")
    print("Offline running-process identity check passed")
} else {
    require(arguments.count == 1, "unknown arguments")
    print("Security requirements compile; distribution fixtures are opt-in via --fixture; live process check via --pid")
}

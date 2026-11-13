import Foundation
import CoreFoundation
/// The complete persistence budget. No target or content fields are accepted.
public struct AutoPreferences {
    public var automaticEnabled: Bool
    public var settings: BlurSettings
    public init(automaticEnabled:Bool = false,settings:BlurSettings = BlurSettings()) { self.automaticEnabled = automaticEnabled;self.settings = settings }
    public enum Invalid: Error { case schema }
    public static func decode(_ data:Data) throws -> AutoPreferences {
        guard data.count <= 2048,let root = try JSONSerialization.jsonObject(with:data) as? [String:Any],
              Set(root.keys) == ["schemaVersion","automaticEnabled","settings"],
              let version = root["schemaVersion"] as? NSNumber,CFGetTypeID(version) != CFBooleanGetTypeID(),version.doubleValue == 1,
              let enabled = boolean(root["automaticEnabled"]),let values = root["settings"] as? [String:Any],
              Set(values.keys) == ["sidebarPreviews","conversationMessages","names","avatars","sidebarHover","conversationHover","tint"],
              let sidebar = boolean(values["sidebarPreviews"]),let conversation = boolean(values["conversationMessages"]),
              let names = boolean(values["names"]),let avatars = boolean(values["avatars"]),
              let sidebarHover = boolean(values["sidebarHover"]),let conversationHover = boolean(values["conversationHover"]),
              let tint = values["tint"] as? NSNumber,CFGetTypeID(tint) != CFBooleanGetTypeID(),tint.doubleValue.isFinite,(0.4...0.9).contains(tint.doubleValue) else { throw Invalid.schema }
        return AutoPreferences(automaticEnabled:enabled,settings:BlurSettings(sidebarPreviews:sidebar,conversationMessages:conversation,names:names,avatars:avatars,sidebarHover:sidebarHover,conversationHover:conversationHover,tint:tint.doubleValue))
    }
    public func encoded() throws -> Data {
        try JSONSerialization.data(withJSONObject:["schemaVersion":1,"automaticEnabled":automaticEnabled,"settings":[
            "sidebarPreviews":settings.sidebarPreviews,"conversationMessages":settings.conversationMessages,
            "names":settings.names,"avatars":settings.avatars,"sidebarHover":settings.sidebarHover,
            "conversationHover":settings.conversationHover,"tint":settings.tint]],options:[.sortedKeys])
    }
    private static func boolean(_ value:Any?) -> Bool? {
        guard let n = value as? NSNumber,CFGetTypeID(n) == CFBooleanGetTypeID() else { return nil };return n.boolValue
    }
}

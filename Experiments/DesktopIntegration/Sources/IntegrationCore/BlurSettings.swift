import Foundation
public enum BlurCategory: CaseIterable { case sidebarPreview, conversationMessage, contactName, avatar }
public struct BlurSettings {
    public var sidebarPreviews: Bool
    public var conversationMessages: Bool
    public var names: Bool
    public var avatars: Bool
    public var sidebarHover: Bool
    public var conversationHover: Bool
    private var tintValue: Double
    public var tint: Double {
        get { tintValue }
        set { tintValue = Self.normalizedTint(newValue) }
    }
    private static func normalizedTint(_ value: Double) -> Double { value.isFinite ? min(0.9, max(0.4, value)) : 0.65 }
    public init(sidebarPreviews: Bool = true, conversationMessages: Bool = true, names: Bool = false, avatars: Bool = false,
                sidebarHover: Bool = false, conversationHover: Bool = false, tint: Double = 0.65) {
        self.sidebarPreviews = sidebarPreviews; self.conversationMessages = conversationMessages
        self.names = names; self.avatars = avatars; self.sidebarHover = sidebarHover; self.conversationHover = conversationHover; self.tintValue = Self.normalizedTint(tint)
    }
    public var needsCapture: Bool { sidebarPreviews || conversationMessages || names || avatars }
    public func isEnabled(_ category: BlurCategory) -> Bool {
        switch category {
        case .sidebarPreview: return sidebarPreviews
        case .conversationMessage: return conversationMessages
        case .contactName: return names
        case .avatar: return avatars
        }
    }
    public func permitsHover(_ category: BlurCategory) -> Bool {
        switch category {
        case .sidebarPreview: return sidebarPreviews && sidebarHover
        case .conversationMessage: return conversationMessages && conversationHover
        case .contactName, .avatar: return false
        }
    }
}

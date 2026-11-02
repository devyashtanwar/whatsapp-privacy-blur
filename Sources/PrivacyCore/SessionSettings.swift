import Foundation

/// Deliberately has no persistence adapter. Every launch starts with privacy defaults.
public final class SessionSettings {
    public var enabled = true
    public var fullWindow = true
    public var hoverReveal = false
    public var width: CGFloat = 308
    public init() {}
    public var configuration: CoverConfiguration {
        .init(enabled: enabled, fullWindow: fullWindow, hoverReveal: hoverReveal, sidebarWidth: width)
    }
}

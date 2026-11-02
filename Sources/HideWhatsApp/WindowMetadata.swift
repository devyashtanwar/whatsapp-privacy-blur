import AppKit
import PrivacyCore

final class WindowMetadataSource: WindowSource {
    static let bundleID = "net.whatsapp.WhatsApp"
    private let coverTarget: (Int) -> UInt32?
    private let identity = ProcessIdentityProvider()
    private(set) var hasUntrustedTarget = false

    init(coverTarget: @escaping (Int) -> UInt32?) { self.coverTarget = coverTarget }
    func invalidateIdentityCache() { identity.invalidate() }

    static var targetApplications: [NSRunningApplication] {
        NSWorkspace.shared.runningApplications.filter { $0.bundleIdentifier == bundleID && !$0.isTerminated }
    }
    private func empty() -> WindowEnvironment {
        .init(windows: [], primaryDisplayMaxY: .nan, targetIsFrontmost: false, mouseLocation: .zero)
    }

    func snapshot(includeHover: Bool) -> WindowEnvironment {
        precondition(Thread.isMainThread)
        let applications = Self.targetApplications.filter { !$0.isHidden }
        let authenticated = identity.trustedPIDs(applications)
        hasUntrustedTarget = !applications.isEmpty && authenticated.isEmpty
        guard !authenticated.isEmpty else { return empty() }
        let records = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements],
                                                 kCGNullWindowID) as? [[String: Any]] ?? []
        // Recheck process generations after reading the window server snapshot.
        let current = Set(applications.filter { authenticated.contains($0.processIdentifier) && ProcessIdentityProvider.stillCurrent($0) }.map(\.processIdentifier))
        let foregroundPID = NSWorkspace.shared.frontmostApplication?.processIdentifier
        let (mouse, hovered) = HoverSampling.sample(enabled: includeHover, location: { NSEvent.mouseLocation }, window: {
            let hit = NSWindow.windowNumber(at: NSEvent.mouseLocation, belowWindowWithWindowNumber: 0)
            return self.coverTarget(hit) ?? UInt32(exactly: hit)
        })
        var result = WindowEnvironment(windows: WindowMetadataDecoder.decode(records, ownerPIDs: current),
            primaryDisplayMaxY: NSScreen.screens.first?.frame.maxY ?? .nan,
            targetIsFrontmost: TrustedProcessRegistry.isTrustedForeground(foregroundPID, allowed: current),
            mouseLocation: mouse)
        result.hoveredWindowID = hovered
        return result
    }
}

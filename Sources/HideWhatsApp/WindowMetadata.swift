import AppKit
import PrivacyCore

final class WindowMetadataSource: WindowSource {
    static let bundleID = "net.whatsapp.WhatsApp"
    private let coverTarget: (Int) -> UInt32?

    init(coverTarget: @escaping (Int) -> UInt32?) { self.coverTarget = coverTarget }

    static var targetApplications: [NSRunningApplication] {
        NSWorkspace.shared.runningApplications.filter { $0.bundleIdentifier == bundleID && !$0.isTerminated }
    }

    func snapshot() -> WindowEnvironment {
        precondition(Thread.isMainThread)
        let applications = Self.targetApplications
        let pids = Set(applications.filter { !$0.isHidden }.map(\.processIdentifier))
        // Only geometry/ownership is read. Do not request window names or pixels.
        let records = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements],
                                                 kCGNullWindowID) as? [[String: Any]] ?? []
        let mouse = NSEvent.mouseLocation
        let hit = NSWindow.windowNumber(at: mouse, belowWindowWithWindowNumber: 0)
        var environment = WindowEnvironment(
            windows: WindowMetadataDecoder.decode(records, ownerPIDs: pids),
            primaryDisplayMaxY: NSScreen.screens.first?.frame.maxY ?? .nan,
            targetIsFrontmost: NSWorkspace.shared.frontmostApplication?.bundleIdentifier == Self.bundleID,
            mouseLocation: mouse
        )
        environment.hoveredWindowID = coverTarget(hit) ?? UInt32(exactly: hit)
        return environment
    }
}

import AppKit
import PrivacyCore

private final class CoverWindow: NSWindow {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    init() {
        super.init(contentRect: .zero, styleMask: .borderless, backing: .buffered, defer: false)
        isReleasedWhenClosed = false
        level = .normal
        backgroundColor = NSColor(calibratedWhite: 0.12, alpha: 1)
        isOpaque = true
        hasShadow = false
        ignoresMouseEvents = false
        animationBehavior = .none
        collectionBehavior = [.transient, .ignoresCycle, .fullScreenAuxiliary]
    }
}

/// Owns only opaque windows. It never captures or receives image pixels.
final class CoverRenderer: CoverSink {
    private var covers: [UInt32: [CoverWindow]] = [:]
    var trackedWindowCount: Int { covers.count }

    func targetWindow(for coverNumber: Int) -> UInt32? {
        covers.first { $0.value.contains { $0.windowNumber == coverNumber } }?.key
    }

    func apply(_ plans: [CoverPlan]) {
        precondition(Thread.isMainThread)
        let wanted = Set(plans.map(\.windowID))
        for id in Array(covers.keys) where !wanted.contains(id) {
            covers.removeValue(forKey: id)?.forEach { $0.close() }
        }
        // Source ordering is front-to-back. Render back-to-front, preserving
        // the relative order of distinct WhatsApp windows.
        for plan in plans.reversed() {
            var windows = covers[plan.windowID] ?? []
            while windows.count > plan.regions.count { windows.removeLast().close() }
            while windows.count < plan.regions.count { windows.append(CoverWindow()) }
            for (window, region) in zip(windows, plan.regions) {
                window.setFrame(region, display: true)
                // No fade: cover immediately when focus/hover state changes.
                window.alphaValue = plan.revealed ? 0 : 1
                window.ignoresMouseEvents = plan.revealed
                window.order(.above, relativeTo: Int(plan.windowID))
            }
            covers[plan.windowID] = windows
        }
    }

    deinit { covers.values.flatMap { $0 }.forEach { $0.close() } }
}

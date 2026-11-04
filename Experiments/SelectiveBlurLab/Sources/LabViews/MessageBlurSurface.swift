import AppKit
import LabPolicy

/// The effect participates in its message's scroll transform and ancestor clipping.
/// No independent screen-space window or geometry timer is involved.
public final class ClickThroughEffect: NSVisualEffectView {
    public override func hitTest(_ point: NSPoint) -> NSView? { nil }
}
public final class MessageBlurSurface: NSView {
    public let regionID: Int
    private let messageContent: NSView
    public let effect = ClickThroughEffect()
    public var isBlurred: Bool { !effect.isHidden }
    public init(id: Int, content: NSView, frame: CGRect) {
        regionID = id; messageContent = content
        super.init(frame: frame)
        content.frame = bounds; content.autoresizingMask = [.width, .height]
        addSubview(content)
        effect.frame = bounds; effect.autoresizingMask = [.width, .height]
        effect.blendingMode = .withinWindow; effect.state = .active; effect.material = .popover
        addSubview(effect) // Protected before this container is attached/displayed.
    }
    public override func resizeSubviews(withOldSize oldSize: NSSize) {
        super.resizeSubviews(withOldSize: oldSize)
        // Autoresizing may round child frames on older AppKit versions. Keep
        // both views at the same exact local bounds, including fractional sizes.
        if messageContent.frame != bounds { messageContent.frame = bounds }
        if effect.frame != bounds { effect.frame = bounds }
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) unavailable") }
    public func setBlurred(_ blurred: Bool) {
        if effect.isHidden == blurred { effect.isHidden = !blurred }
    }
}

/// Owns reveal state only. Scroll positioning remains entirely in AppKit's view tree.
public final class BlurPresentation {
    public private(set) var surfaces: [MessageBlurSurface] = []
    private let lease = RevealLease()
    private var focused = false
    private var hoverEnabled = false
    private var geometryAvailable = true
    private var scrolling = Set<Int>()
    private var epoch = 0
    private var pointerItem: Int?
    public init() {}
    public func replace(_ surfaces: [MessageBlurSurface]) {
        layoutWillChange(); self.surfaces = surfaces; render(nil)
    }
    public func setFocus(_ active: Bool) {
        guard focused != active else { return }
        focused = active
        if !active { scrolling.removeAll() }
        layoutWillChange()
    }
    public func setHoverEnabled(_ enabled: Bool) {
        guard hoverEnabled != enabled else { return }
        hoverEnabled = enabled; layoutWillChange()
    }
    public func setGeometryAvailable(_ available: Bool) {
        guard geometryAvailable != available else { return }
        geometryAvailable = available; layoutWillChange()
    }
    public func pointerMoved(item: Int?, now: TimeInterval) {
        guard scrolling.isEmpty, focused, hoverEnabled, geometryAvailable else {
            lease.suspend(); pointerItem = nil; render(nil); return
        }
        let known = surfaces.contains { $0.regionID == item } ? item : nil
        pointerItem = known
        render(lease.update(item: known, active: true, epoch: epoch, now: now))
    }
    public func tick(now: TimeInterval) {
        // Expiry only: never discover geometry or acquire a new hover on a timer.
        guard let item = pointerItem, focused, hoverEnabled, geometryAvailable, scrolling.isEmpty else {
            render(nil); return
        }
        render(lease.update(item: item, active: true, epoch: epoch, now: now))
    }
    public func layoutWillChange() {
        epoch += 1; pointerItem = nil; lease.suspend(); render(nil)
    }
    public func beginScroll(_ token: Int) { scrolling.insert(token); layoutWillChange() }
    public func endScroll(_ token: Int) { scrolling.remove(token); layoutWillChange() }
    private func render(_ revealed: Int?) {
        for surface in surfaces {
            // Explicit unsupported demo mode shows no masking; never claims protection.
            surface.setBlurred(geometryAvailable && surface.regionID != revealed)
        }
    }
}

/// Revoke reveal before movement, including programmatic/legacy input with no
/// live-scroll start/end notifications. Bounds notifications provide a backstop.
public final class ScrollAwareClipView: NSClipView {
    public var onWillChange: (() -> Void)?
    public override func scroll(to newOrigin: NSPoint) {
        // NSClipView.scroll(to:) does not necessarily dispatch setBoundsOrigin.
        if newOrigin != bounds.origin { onWillChange?() }
        super.scroll(to: newOrigin)
    }
    public override func setBoundsOrigin(_ newOrigin: NSPoint) {
        if newOrigin != bounds.origin { onWillChange?() }
        super.setBoundsOrigin(newOrigin)
    }
    public override func setBoundsSize(_ newSize: NSSize) {
        if newSize != bounds.size { onWillChange?() }
        super.setBoundsSize(newSize)
    }
}

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
    public let gaussian: GaussianMessageView
    private var blurred = true
    public private(set) var usesGaussian = true
    public var isBlurred: Bool { usesGaussian ? !gaussian.isHidden : !effect.isHidden }
    public init(id: Int, content: NSView, frame: CGRect) {
        regionID = id; messageContent = content
        let field = content as? NSTextField
        gaussian = GaussianMessageView(text: field?.stringValue ?? "Generated fixture", fontSize: field?.font?.pointSize ?? 14,
                                       bubble: field.flatMap { $0.drawsBackground ? $0.backgroundColor : nil } ?? .textBackgroundColor,
                                       frame: CGRect(origin: .zero, size: frame.size))
        super.init(frame: frame)
        content.frame = bounds; content.autoresizingMask = [.width, .height]
        addSubview(content)
        effect.frame = bounds; effect.autoresizingMask = [.width, .height]
        effect.blendingMode = .withinWindow; effect.state = .active; effect.material = .popover
        addSubview(effect)
        gaussian.autoresizingMask = [.width, .height]; addSubview(gaussian)
        applyVisibility() // Protected before this container is attached/displayed.
    }
    public override func resizeSubviews(withOldSize oldSize: NSSize) {
        super.resizeSubviews(withOldSize: oldSize)
        // Autoresizing may round child frames on older AppKit versions. Keep
        // both views at the same exact local bounds, including fractional sizes.
        if messageContent.frame != bounds { messageContent.frame = bounds }
        if effect.frame != bounds { effect.frame = bounds }
        if gaussian.frame != bounds { gaussian.frame = bounds }
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) unavailable") }
    public func setBlurred(_ value: Bool) { blurred = value; applyVisibility() }
    public func setStyle(gaussian enabled: Bool, tint: Double, material: NSVisualEffectView.Material) {
        usesGaussian = enabled
        if effect.material != material { effect.material = material }
        gaussian.tintOpacity = tint
        applyVisibility()
    }
    private func applyVisibility() {
        // Show the selected obscuring surface before hiding the previous style.
        if usesGaussian { gaussian.isHidden = !blurred; effect.isHidden = true }
        else { effect.isHidden = !blurred; gaussian.isHidden = true }
    }
}

/// Owns reveal state only. Scroll positioning remains entirely in AppKit's view tree.
public final class BlurPresentation {
    public private(set) var surfaces: [MessageBlurSurface] = []
    private let recovery = HoverRecovery()
    private var focused = false
    private var hoverEnabled = false
    private var geometryAvailable = true
    public var waitingForScroll: Bool { recovery.waitingForScroll }
    public init() {}
    public func replace(_ surfaces: [MessageBlurSurface]) {
        layoutWillChange(); self.surfaces = surfaces; render(nil)
    }
    public func setFocus(_ active: Bool) {
        guard focused != active else { return }
        focused = active; syncPermissions()
    }
    public func setHoverEnabled(_ enabled: Bool) {
        guard hoverEnabled != enabled else { return }
        hoverEnabled = enabled; syncPermissions()
    }
    public func setGeometryAvailable(_ available: Bool) {
        guard geometryAvailable != available else { return }
        geometryAvailable = available; layoutWillChange(); syncPermissions()
    }
    private func syncPermissions() {
        recovery.setPermitted(focused && hoverEnabled && geometryAvailable)
        render(recovery.revealedID)
    }
    public func pointerMoved(item: Int?, position: CGPoint, now: TimeInterval) {
        let known = surfaces.contains { $0.regionID == item } ? item : nil
        render(recovery.pointer(item: known, position: position, now: now))
    }
    public func pointerExited(now: TimeInterval) { recovery.exit(now: now); render(nil) }
    public func tick(now: TimeInterval) { render(recovery.tick(now: now)) }
    public func layoutWillChange() { recovery.invalidate(); render(nil) }
    public func scroll(_ signal: ScrollSignal, in pane: Int, now: TimeInterval) {
        recovery.scroll(signal, in: pane, now: now); render(recovery.revealedID)
    }
    private func render(_ revealed: Int?) {
        for surface in surfaces {
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

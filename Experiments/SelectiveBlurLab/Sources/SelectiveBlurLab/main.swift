import AppKit
import Security
import LabPolicy
import LabViews

// Synthetic-only experiment. No WhatsApp discovery, capture, Accessibility,
// global input monitor, file access, network client or login registration.
final class FlippedView: NSView { override var isFlipped: Bool { true } }
// Local fixture input only; no global monitor or keyboard inspection.
final class PointerWindow: NSWindow {
    var onPointer: ((NSPoint) -> Void)?
    var onScroll: ((NSEvent.Phase, NSEvent.Phase, NSPoint) -> Void)?
    override func sendEvent(_ event: NSEvent) {
        if let location = FixturePointerEvents.location(for: event) {
            onPointer?(location)
        } else if event.type == .scrollWheel { onScroll?(event.phase, event.momentumPhase, event.locationInWindow) }
        super.sendEvent(event)
    }
}
final class TrackingRootView: NSView {
    var onExit: (() -> Void)?
    private var area: NSTrackingArea?
    override func updateTrackingAreas() {
        if let area = area { removeTrackingArea(area) }
        let next = NSTrackingArea(rect: bounds, options: [.activeAlways, .inVisibleRect, .mouseEnteredAndExited], owner: self, userInfo: nil)
        addTrackingArea(next); area = next; super.updateTrackingAreas()
    }
    override func mouseExited(with event: NSEvent) { onExit?() }
}

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
          let entitlements = info[kSecCodeInfoEntitlementsDict as String] as? [String: Any], entitlements.count == 1,
          let sandbox = entitlements["com.apple.security.app-sandbox"] as? NSNumber,
          CFGetTypeID(sandbox) == CFBooleanGetTypeID(), sandbox.boolValue,
          let flags = info[kSecCodeInfoFlags as String] as? NSNumber, flags.uint32Value & 0x10000 != 0,
          Bundle.main.bundleIdentifier == "devyashtanwar.selective-blur-lab" else { return false }
    return true
}

final class Lab: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private var window: PointerWindow!
    private let sidebar = NSScrollView()
    private let conversation = NSScrollView()
    private let rowCount = NSPopUpButton()
    private let material = NSPopUpButton()
    private let tint = NSSlider(value: 0.65, minValue: 0.6, maxValue: 0.7, target: nil, action: nil)
    private let tintLabel = NSTextField(labelWithString: "Tint 65%")
    private let evidence = NSPopUpButton()
    private let hover = NSButton(checkboxWithTitle: "Reveal hovered item (2s max)", target: nil, action: nil)
    private let status = NSTextField(labelWithString: "")
    private let composer = NSTextField(string: "Type here to check that controls remain usable")
    private var targets: [(MessageBlurSurface, NSClipView)] = []
    private let presentation = BlurPresentation()
    private var timer: Timer?
    private var observers: [NSObjectProtocol] = []
    private var scale: CGFloat = 1
    private var rotation = 0

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard confinementAllowed() else {
            let alert = NSAlert(); alert.messageText = "Use the signed sandboxed lab bundle"
            alert.informativeText = "The raw executable is refused. No demo windows or permissions have been enabled."
            alert.runModal(); NSApp.terminate(nil); return
        }
        NSApp.setActivationPolicy(.regular)
        let menu = NSMenu(); let appItem = NSMenuItem(); menu.addItem(appItem)
        let appMenu = NSMenu(); appMenu.addItem(withTitle: "Quit Selective Blur Lab", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu; NSApp.mainMenu = menu
        window = PointerWindow(contentRect: NSRect(x: 120, y: 120, width: 1120, height: 760), styleMask: [.titled, .closable, .resizable, .miniaturizable], backing: .buffered, defer: false)
        window.title = "Selective Blur Lab — invented chats only; does not protect WhatsApp"
        window.minSize = NSSize(width: 1120, height: 650); window.isReleasedWhenClosed = false; window.delegate = self
        let root = TrackingRootView(frame: CGRect(origin: .zero, size: window.contentView!.bounds.size))
        window.contentView = root; window.acceptsMouseMovedEvents = true
        window.onPointer = { [weak self] point in self?.pointerMoved(point) }
        window.onScroll = { [weak self] phase, momentum, point in self?.scrollPhase(phase, momentum: momentum, point: point) }
        root.onExit = { [weak self] in self?.pointerMoved(nil) }
        let intro = text("FEASIBILITY DEMO • Names stay clear • Only generated message regions get material blur", x: 16, y: 718, width: 1090, height: 22)
        root.addSubview(intro); intro.autoresizingMask = [.width, .minYMargin]
        rowCount.addItems(withTitles: ["1 row", "10 rows", "30 rows"]); rowCount.selectItem(at: 1)
        configure(rowCount, frame: NSRect(x: 16, y: 680, width: 95, height: 28), action: #selector(rebuild))
        material.addItems(withTitles: ["Gaussian blur", "Popover material", "HUD material", "Sheet material"])
        configure(material, frame: NSRect(x: 120, y: 680, width: 175, height: 28), action: #selector(controlsChanged))
        configure(hover, frame: NSRect(x: 310, y: 680, width: 250, height: 28), action: #selector(controlsChanged))
        evidence.addItems(withTitles: ["Known synthetic view geometry", "Window bounds only — unsupported"])
        configure(evidence, frame: NSRect(x: 570, y: 680, width: 315, height: 28), action: #selector(controlsChanged))
        let change = NSButton(title: "Reorder", target: self, action: #selector(reorder))
        configure(change, frame: NSRect(x: 895, y: 680, width: 90, height: 28), action: #selector(reorder))
        let zoomButton = NSButton(title: "Text size", target: self, action: #selector(zoom))
        configure(zoomButton, frame: NSRect(x: 990, y: 680, width: 110, height: 28), action: #selector(zoom))
        let name = text("Demo contacts", x: 16, y: 635, width: 300, height: 26)
        let header = text("Alex — generated conversation", x: 350, y: 635, width: 280, height: 26)
        for view in [name, header] { root.addSubview(view); view.autoresizingMask = [.minYMargin] }
        tint.isContinuous = false
        configure(tint, frame: NSRect(x: 650, y: 637, width: 230, height: 26), action: #selector(controlsChanged))
        tintLabel.frame = NSRect(x: 650, y: 663, width: 230, height: 16)
        tintLabel.font = .systemFont(ofSize: 11); tintLabel.textColor = .secondaryLabelColor
        tintLabel.autoresizingMask = [.minYMargin]; root.addSubview(tintLabel)
        let theme = NSButton(title: "Toggle light / dark", target: self, action: #selector(changeTheme))
        configure(theme, frame: NSRect(x: 895, y: 637, width: 205, height: 28), action: #selector(changeTheme))
        sidebar.frame = NSRect(x: 16, y: 85, width: 315, height: 540)
        conversation.frame = NSRect(x: 350, y: 85, width: 750, height: 540)
        for (token, scroll) in [sidebar, conversation].enumerated() {
            let clip = ScrollAwareClipView(frame: scroll.contentView.frame)
            clip.onWillChange = { [weak self] in self?.presentation.scroll(.move, in: token, now: ProcessInfo.processInfo.systemUptime) }
            scroll.contentView = clip
            clip.postsBoundsChangedNotifications = true
            observe(NSView.boundsDidChangeNotification, object: clip) { [weak self] in self?.presentation.scroll(.move, in: token, now: ProcessInfo.processInfo.systemUptime) }
            observe(NSScrollView.willStartLiveScrollNotification, object: scroll) { [weak self] in self?.presentation.scroll(.prepare, in: token, now: ProcessInfo.processInfo.systemUptime) }
            observe(NSScrollView.didLiveScrollNotification, object: scroll) { [weak self] in self?.presentation.scroll(.move, in: token, now: ProcessInfo.processInfo.systemUptime) }
            observe(NSScrollView.didEndLiveScrollNotification, object: scroll) { [weak self] in self?.presentation.scroll(.end, in: token, now: ProcessInfo.processInfo.systemUptime) }
            scroll.hasVerticalScroller = true; scroll.drawsBackground = true
            scroll.backgroundColor = .textBackgroundColor; scroll.borderType = .bezelBorder
            scroll.autoresizingMask = [.height]; root.addSubview(scroll)
        }
        conversation.autoresizingMask = [.width, .height]
        composer.frame = NSRect(x: 350, y: 47, width: 750, height: 28)
        composer.autoresizingMask = [.width]; root.addSubview(composer)
        status.frame = NSRect(x: 16, y: 10, width: 1090, height: 26)
        status.font = .systemFont(ofSize: 12); status.autoresizingMask = [.width]; root.addSubview(status)
        rebuild()
        window.makeKeyAndOrderFront(nil)
        // This timer expires a reveal only. It does not move, discover or rebuild masks.
        timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            self?.presentation.tick(now: ProcessInfo.processInfo.systemUptime)
            self?.updateStatus()
        }
        RunLoop.main.add(timer!, forMode: .common)
    }

    private func text(_ string: String, x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat) -> NSTextField {
        let field = NSTextField(wrappingLabelWithString: string)
        field.frame = NSRect(x: x, y: y, width: width, height: height)
        field.font = .systemFont(ofSize: 14 * scale); return field
    }
    private func configure(_ control: NSControl, frame: NSRect, action: Selector) {
        control.frame = frame; control.target = self; control.action = action
        control.autoresizingMask = [.minYMargin]; window.contentView!.addSubview(control)
    }
    @objc private func changeTheme() {
        let dark = window.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
        window.appearance = NSAppearance(named: dark ? .aqua : .darkAqua)
        presentation.layoutWillChange(); controlsChanged()
    }
    @objc private func reorder() { rotation += 1; rebuild() }
    @objc private func zoom() { scale = scale == 1 ? 1.25 : 1; rebuild() }
    @objc private func rebuild() {
        presentation.layoutWillChange(); targets.removeAll()
        let count = [1, 10, 30][rowCount.indexOfSelectedItem]
        let rows = FlippedView(frame: NSRect(x: 0, y: 0, width: 290, height: CGFloat(count) * 84 * scale))
        for index in 0..<count {
            let y = CGFloat(index) * 84 * scale
            let label = text("Contact \((index + rotation) % count + 1)", x: 14, y: y + 8, width: 265, height: 22 * scale)
            let preview = text(index % 3 == 0 ? "A generated preview with a long link" : "Invented message preview \(index + 1)", x: 14, y: y + 37 * scale, width: 265, height: 30 * scale)
            let surface = MessageBlurSurface(id: index, content: preview, frame: preview.frame)
            rows.addSubview(label); rows.addSubview(surface)
            targets.append((surface, sidebar.contentView))
        }
        sidebar.documentView = rows
        let messages = FlippedView(frame: NSRect(x: 0, y: 0, width: 690, height: 2100 * scale))
        for index in 0..<16 {
            let y = CGFloat(index) * 125 * scale + 12
            let x: CGFloat = index % 2 == 0 ? 24 : 170
            let body = text(index % 4 == 0 ? "Generated attachment caption\n[Invented media card — no file loaded]" : "Invented message \(index + 1)\nMeeting at the imaginary cafe.\nThis is synthetic test text.", x: x, y: y, width: 450, height: 90 * scale)
            body.isSelectable = true; body.drawsBackground = true
            body.backgroundColor = index % 2 == 0 ? .controlBackgroundColor : NSColor.systemGreen.withAlphaComponent(0.15)
            let surface = MessageBlurSurface(id: 1000 + index, content: body, frame: body.frame)
            messages.addSubview(surface); targets.append((surface, conversation.contentView))
        }
        conversation.documentView = messages
        presentation.replace(targets.map { $0.0 }); controlsChanged()
    }
    private func windowRect(_ view: NSView, clippedBy clip: NSClipView?) -> CGRect? {
        var rect = view.convert(view.bounds, to: nil)
        if let clip = clip { rect = rect.intersection(clip.convert(clip.bounds, to: nil)) }
        guard !rect.isNull, rect.width > 0, rect.height > 0 else { return nil }
        return rect
    }
    private func observe(_ name: Notification.Name, object: AnyObject, action: @escaping () -> Void) {
        observers.append(NotificationCenter.default.addObserver(forName: name, object: object, queue: .main) { _ in action() })
    }
    private func scrollPhase(_ phase: NSEvent.Phase, momentum: NSEvent.Phase, point: NSPoint) {
        guard let pane = [sidebar, conversation].firstIndex(where: { $0.convert($0.bounds, to: nil).contains(point) }),
              let signal = FixtureScrollEvents.signal(phase: phase, momentum: momentum) else { return }
        presentation.scroll(signal, in: pane, now: ProcessInfo.processInfo.systemUptime)
    }
    private func pointerMoved(_ point: NSPoint?) {
        presentation.setFocus(NSApp.isActive && window.isKeyWindow)
        guard let point = point else { presentation.pointerExited(now: ProcessInfo.processInfo.systemUptime); return }
        let item = targets.first { surface, clip in windowRect(surface, clippedBy: clip)?.contains(point) == true }?.0.regionID
        presentation.pointerMoved(item: item, position: point, now: ProcessInfo.processInfo.systemUptime)
    }
    @objc private func controlsChanged() {
        presentation.setHoverEnabled(hover.state == .on)
        presentation.setGeometryAvailable(evidence.indexOfSelectedItem == 0)
        let gaussian = material.indexOfSelectedItem == 0
        let selected: NSVisualEffectView.Material = [.popover, .popover, .hudWindow, .sheet][material.indexOfSelectedItem]
        tint.isEnabled = gaussian; tintLabel.stringValue = "Tint \(Int((tint.doubleValue * 100).rounded()))% — blurred base stays opaque"
        for (surface, _) in targets { surface.setStyle(gaussian: gaussian, tint: tint.doubleValue, material: selected) }
        updateStatus()
    }
    private func updateStatus() {
        if evidence.indexOfSelectedItem != 0 {
            status.stringValue = "UNSUPPORTED: window bounds do not locate messages. No masks; not protected."
        } else if targets.contains(where: { $0.0.usesGaussian && $0.0.gaussian.renderFailed }) {
            status.stringValue = "Gaussian rendering unavailable — generated content remains covered • Synthetic only"
        } else if hover.state == .on && presentation.waitingForScroll {
            status.stringValue = "Hover paused while scrolling settles — move over a message afterward • Synthetic only"
        } else {
            status.stringValue = "Synthetic blur • Move over a message after scrolling stops • Appearance still needs review • Does not protect WhatsApp"
        }
    }
    func windowDidBecomeKey(_ notification: Notification) { presentation.setFocus(NSApp.isActive) }
    func windowDidResignKey(_ notification: Notification) { presentation.setFocus(false) }
    func applicationWillResignActive(_ notification: Notification) { presentation.setFocus(false) }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
    func windowWillClose(_ notification: Notification) {
        presentation.setFocus(false); timer?.invalidate(); timer = nil
        observers.forEach { NotificationCenter.default.removeObserver($0) }; observers.removeAll()
    }
}
let app = NSApplication.shared
let delegate = Lab()
app.delegate = delegate
app.run()

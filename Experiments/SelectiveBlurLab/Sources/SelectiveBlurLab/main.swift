import AppKit
import Security
import LabPolicy

// Synthetic-only experiment. No WhatsApp discovery, capture, Accessibility,
// global input monitor, file access, network client or login registration.
final class FlippedView: NSView { override var isFlipped: Bool { true } }
final class EffectWindow: NSWindow {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
    let effect = NSVisualEffectView()
    init() {
        super.init(contentRect: .zero, styleMask: .borderless, backing: .buffered, defer: false)
        isReleasedWhenClosed = false; isOpaque = false; backgroundColor = .clear
        hasShadow = false; ignoresMouseEvents = true; level = .normal
        collectionBehavior = [.transient, .ignoresCycle, .fullScreenAuxiliary]
        animationBehavior = .none
        effect.blendingMode = .behindWindow; effect.state = .active
        effect.material = .popover; contentView = effect
    }
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
    private var window: NSWindow!
    private let sidebar = NSScrollView()
    private let conversation = NSScrollView()
    private let rowCount = NSPopUpButton()
    private let material = NSPopUpButton()
    private let evidence = NSPopUpButton()
    private let hover = NSButton(checkboxWithTitle: "Reveal hovered item (2s max)", target: nil, action: nil)
    private let status = NSTextField(labelWithString: "")
    private let composer = NSTextField(string: "Type here to check that controls remain usable")
    private var masks: [(Int, NSView, NSClipView)] = []
    private var readable: [(NSView, NSClipView?)] = []
    private var overlays: [Int: EffectWindow] = [:]
    private var timer: Timer?
    private let lease = RevealLease()
    private var previous: [Region] = []
    private var epoch = 0
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
        window = NSWindow(contentRect: NSRect(x: 120, y: 120, width: 1120, height: 760), styleMask: [.titled, .closable, .resizable, .miniaturizable], backing: .buffered, defer: false)
        window.title = "Selective Blur Lab — invented chats only; does not protect WhatsApp"
        window.minSize = NSSize(width: 1120, height: 650); window.isReleasedWhenClosed = false; window.delegate = self
        let root = window.contentView!
        let intro = text("FEASIBILITY DEMO • Names stay clear • Only generated message regions get material blur", x: 16, y: 718, width: 1090, height: 22)
        root.addSubview(intro); intro.autoresizingMask = [.width, .minYMargin]
        rowCount.addItems(withTitles: ["1 row", "10 rows", "30 rows"]); rowCount.selectItem(at: 1)
        configure(rowCount, frame: NSRect(x: 16, y: 680, width: 95, height: 28), action: #selector(rebuild))
        material.addItems(withTitles: ["Popover material", "HUD material", "Sheet material"])
        configure(material, frame: NSRect(x: 120, y: 680, width: 175, height: 28), action: #selector(refresh))
        configure(hover, frame: NSRect(x: 310, y: 680, width: 250, height: 28), action: #selector(refresh))
        evidence.addItems(withTitles: ["Known synthetic view geometry", "Window bounds only — unsupported"])
        configure(evidence, frame: NSRect(x: 570, y: 680, width: 315, height: 28), action: #selector(refresh))
        let change = NSButton(title: "Reorder", target: self, action: #selector(reorder))
        configure(change, frame: NSRect(x: 895, y: 680, width: 90, height: 28), action: #selector(reorder))
        let zoomButton = NSButton(title: "Text size", target: self, action: #selector(zoom))
        configure(zoomButton, frame: NSRect(x: 990, y: 680, width: 110, height: 28), action: #selector(zoom))
        let name = text("Demo contacts", x: 16, y: 635, width: 300, height: 26)
        let header = text("Alex — generated conversation", x: 350, y: 635, width: 520, height: 26)
        for view in [name, header] { root.addSubview(view); view.autoresizingMask = [.minYMargin] }
        let theme = NSButton(title: "Toggle light / dark", target: self, action: #selector(changeTheme))
        configure(theme, frame: NSRect(x: 895, y: 637, width: 205, height: 28), action: #selector(changeTheme))
        sidebar.frame = NSRect(x: 16, y: 85, width: 315, height: 540)
        conversation.frame = NSRect(x: 350, y: 85, width: 750, height: 540)
        for scroll in [sidebar, conversation] {
            scroll.hasVerticalScroller = true; scroll.drawsBackground = true
            scroll.backgroundColor = .textBackgroundColor; scroll.borderType = .bezelBorder
            scroll.autoresizingMask = [.height]; root.addSubview(scroll)
        }
        conversation.autoresizingMask = [.width, .height]
        composer.frame = NSRect(x: 350, y: 47, width: 750, height: 28)
        composer.autoresizingMask = [.width]; root.addSubview(composer)
        status.frame = NSRect(x: 16, y: 10, width: 1090, height: 26)
        status.font = .systemFont(ofSize: 12); status.autoresizingMask = [.width]; root.addSubview(status)
        readable = [(intro, nil), (name, nil), (header, nil), (composer, nil)]
        rebuild()
        window.makeKeyAndOrderFront(nil)
        timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in self?.refresh() }
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
        epoch += 1; refresh()
    }
    @objc private func reorder() { rotation += 1; rebuild() }
    @objc private func zoom() { scale = scale == 1 ? 1.25 : 1; rebuild() }
    @objc private func rebuild() {
        masks.removeAll(); readable = Array(readable.prefix(4)); epoch += 1
        let count = [1, 10, 30][rowCount.indexOfSelectedItem]
        let rows = FlippedView(frame: NSRect(x: 0, y: 0, width: 290, height: CGFloat(count) * 84 * scale))
        for index in 0..<count {
            let y = CGFloat(index) * 84 * scale
            let label = text("Contact \((index + rotation) % count + 1)", x: 14, y: y + 8, width: 265, height: 22 * scale)
            let preview = text(index % 3 == 0 ? "A generated preview with a long link" : "Invented message preview \(index + 1)", x: 14, y: y + 37 * scale, width: 265, height: 30 * scale)
            rows.addSubview(label); rows.addSubview(preview)
            readable.append((label, sidebar.contentView)); masks.append((index, preview, sidebar.contentView))
        }
        sidebar.documentView = rows
        let messages = FlippedView(frame: NSRect(x: 0, y: 0, width: 690, height: 2100 * scale))
        for index in 0..<16 {
            let y = CGFloat(index) * 125 * scale + 12
            let x: CGFloat = index % 2 == 0 ? 24 : 170
            let body = text(index % 4 == 0 ? "Generated attachment caption\n[Invented media card — no file loaded]" : "Invented message \(index + 1)\nMeeting at the imaginary cafe.\nThis is synthetic test text.", x: x, y: y, width: 450, height: 90 * scale)
            body.isSelectable = true; body.drawsBackground = true
            body.backgroundColor = index % 2 == 0 ? .controlBackgroundColor : NSColor.systemGreen.withAlphaComponent(0.15)
            messages.addSubview(body); masks.append((1000 + index, body, conversation.contentView))
        }
        conversation.documentView = messages
        refresh()
    }
    private func screenRect(_ view: NSView, clippedBy clip: NSClipView?) -> CGRect? {
        var rect = view.convert(view.bounds, to: nil)
        if let clip = clip { rect = rect.intersection(clip.convert(clip.bounds, to: nil)) }
        guard !rect.isNull, rect.width > 0, rect.height > 0 else { return nil }
        return window.convertToScreen(rect)
    }
    @objc private func refresh() {
        guard window != nil else { return }
        let active = NSApp.isActive && window.isVisible && !window.isMiniaturized
        let regions = masks.compactMap { id, view, clip -> Region? in
            screenRect(view, clippedBy: clip).map { Region(id, $0) }
        }
        if regions != previous { epoch += 1; previous = regions }
        let exclusions = readable.compactMap { screenRect($0.0, clippedBy: $0.1) }
        let now = ProcessInfo.processInfo.systemUptime
        let plan = RegionPlanner.plan(regions, excluding: exclusions, within: window.frame,
                                      evidence: evidence.indexOfSelectedItem == 0 ? .instrumentedFixture : .windowBoundsOnly,
                                      observedAt: now, now: now)
        let ready = active && plan.state == .fixtureReady
        let pointer = hover.state == .on && ready ? NSEvent.mouseLocation : nil
        let top = pointer.map { NSWindow.windowNumber(at: $0, belowWindowWithWindowNumber: 0) }
        let topIsFixture = top == window.windowNumber || overlays.values.contains { $0.windowNumber == top }
        let hit = topIsFixture ? plan.regions.first(where: { $0.frame.contains(pointer ?? .zero) })?.id : nil
        let revealed = lease.update(item: hit, active: ready, epoch: epoch, now: now)
        let wanted = ready ? Set(plan.regions.map(\.id)) : []
        for id in Array(overlays.keys) where !wanted.contains(id) { overlays.removeValue(forKey: id)?.close() }
        for region in plan.regions where ready {
            let overlay = overlays[region.id] ?? EffectWindow()
            overlay.appearance = window.appearance
            overlay.effect.material = [.popover, .hudWindow, .sheet][material.indexOfSelectedItem]
            overlay.setFrame(region.frame, display: true)
            if region.id == revealed { overlay.orderOut(nil) }
            else { overlay.order(.above, relativeTo: window.windowNumber) }
            overlays[region.id] = overlay
        }
        status.stringValue = plan.state == .unsupported ? "UNSUPPORTED: window bounds do not locate messages. No masks; not protected." :
            !active ? "Demo paused while inactive. Does not protect WhatsApp." :
            plan.state != .fixtureReady ? "Invalid/stale demo geometry. Not protected." :
            "Synthetic geometry: \(plan.regions.count) regions • Material blur is NOT yet visually accepted • Does not protect WhatsApp"
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
    func windowWillClose(_ notification: Notification) {
        timer?.invalidate(); timer = nil; overlays.values.forEach { $0.close() }; overlays.removeAll()
    }
}
let app = NSApplication.shared
let delegate = Lab()
app.delegate = delegate
app.run()

import AppKit
import IntegrationCore

private final class SettingsStack: NSStackView { override var isFlipped: Bool { true } }

final class PreviewApp: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private var settings = BlurSettings()
    private let engine = IntegrationCoordinator()
    private var window: NSWindow!
    private var item: NSStatusItem!
    private var switches: [NSButton] = []
    private var hovers: [NSButton] = []
    private let tintLabel = NSTextField(labelWithString: "Tint · 65%")
    private let status = NSTextField(wrappingLabelWithString: "Idle · no window selected or captured")
    private let choose = NSButton(title: "Choose WhatsApp window…", target: nil, action: nil)
    func applicationDidFinishLaunching(_ notification: Notification) {
        window = NSWindow(contentRect: NSRect(x: 0,y: 0,width: 480,height: 760),styleMask: [.titled,.closable,.miniaturizable],backing: .buffered,defer: false)
        window.title = "WhatsApp Blur · Desktop Test"
        window.isReleasedWhenClosed = false; window.delegate = self
        let stack = SettingsStack(); stack.orientation = .vertical; stack.alignment = .leading; stack.spacing = 13
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.edgeInsets = NSEdgeInsets(top: 20,left: 24,bottom: 24,right: 24)
        let scroll = NSScrollView(); scroll.hasVerticalScroller = true; scroll.autohidesScrollers = true
        window.contentView = scroll; scroll.documentView = stack
        NSLayoutConstraint.activate([stack.widthAnchor.constraint(equalTo: scroll.contentView.widthAnchor),
            stack.leadingAnchor.constraint(equalTo: scroll.contentView.leadingAnchor),
            stack.topAnchor.constraint(equalTo: scroll.contentView.topAnchor)])
        func label(_ text: String,_ size: CGFloat = 12,_ weight: NSFont.Weight = .regular) {
            let field = NSTextField(wrappingLabelWithString: text); field.font = .systemFont(ofSize: size,weight: weight)
            field.preferredMaxLayoutWidth = 428; stack.addArrangedSubview(field)
        }
        label("A little privacy. Your familiar WhatsApp.",21,.semibold)
        label("LOCAL DESKTOP TEST · COVERAGE UNVERIFIED",10,.semibold)
        label("Choose one native WhatsApp window. This experimental build blurs detected message regions; missed text or media may remain readable. Test with a harmless conversation before relying on it.")
        label("Messages",14,.semibold)
        for (index,title) in ["Blur sidebar message previews","Blur conversation messages"].enumerated() {
            let button = NSButton(checkboxWithTitle: title,target: self,action: #selector(changed(_:)))
            button.tag = index; button.state = .on; switches.append(button); stack.addArrangedSubview(button)
            let hover = NSButton(checkboxWithTitle: "Reveal hovered \(index == 0 ? "preview" : "message") · up to 2 seconds",target: self,action: #selector(changed(_:)))
            hover.font = .systemFont(ofSize: 11); hover.tag = index; hovers.append(hover); stack.addArrangedSubview(hover)
        }
        label("Identity",14,.semibold)
        for (index,title) in ["Blur contact and group names","Blur avatars"].enumerated() {
            let button = NSButton(checkboxWithTitle: title,target: self,action: #selector(changed(_:)))
            button.tag = index+2; switches.append(button); stack.addArrangedSubview(button)
        }
        label("Names and avatars stay blurred during message hover. Detection is experimental, including identity placement.",11)
        stack.addArrangedSubview(tintLabel)
        let slider = NSSlider(value: 0.65,minValue: 0.4,maxValue: 0.9,target: self,action: #selector(tintChanged(_:)))
        slider.widthAnchor.constraint(equalToConstant: 400).isActive = true; slider.isContinuous = false; stack.addArrangedSubview(slider)
        label("40% — 90% tint, over opaque Gaussian blur. No sharp-source transparency.",11)
        status.font = .systemFont(ofSize: 12,weight: .medium); status.textColor = .systemOrange
        status.preferredMaxLayoutWidth = 428; stack.addArrangedSubview(status)
        choose.target = self; choose.action = #selector(selectWindow); choose.bezelStyle = .rounded; stack.addArrangedSubview(choose)
        let actions = NSStackView(); actions.orientation = .horizontal; actions.spacing = 12
        actions.addArrangedSubview(NSButton(title: "Pause / stop access",target: self,action: #selector(stopAccess)))
        actions.addArrangedSubview(NSButton(title: "Privacy limits…",target: self,action: #selector(privacyLimits)))
        stack.addArrangedSubview(actions)
        label("Pixels and on-device OCR stay in memory. No telemetry, network, saving, microphone or Accessibility. Closing this window stops access. Settings reset on quit.",11)
        engine.capture.onStatus = { [weak self] text,busy in
            self?.status.stringValue = text; self?.choose.isEnabled = !busy && (self?.settings.needsCapture ?? false)
        }
        engine.onStatus = { [weak self] in self?.status.stringValue = $0 }
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(systemSymbolName: "eye.slash",accessibilityDescription: "WhatsApp Blur · experimental test")
        let menu = NSMenu()
        let open = NSMenuItem(title: "WhatsApp Blur · settings",action: #selector(showWindow),keyEquivalent: ""); open.target = self; menu.addItem(open)
        let stop = NSMenuItem(title: "Pause / stop window access",action: #selector(stopAccess),keyEquivalent: ""); stop.target = self; menu.addItem(stop)
        menu.addItem(.separator())
        let quit = NSMenuItem(title: "Quit",action: #selector(quit),keyEquivalent: "q"); quit.target = self; menu.addItem(quit); item.menu = menu
        window.center(); showWindow()
    }
    @objc private func changed(_ sender: NSButton) {
        settings.sidebarPreviews = switches[0].state == .on; settings.conversationMessages = switches[1].state == .on
        settings.names = switches[2].state == .on; settings.avatars = switches[3].state == .on
        settings.sidebarHover = hovers[0].state == .on; settings.conversationHover = hovers[1].state == .on
        hovers[0].isEnabled = settings.sidebarPreviews; hovers[1].isEnabled = settings.conversationMessages
        engine.update(settings); choose.isEnabled = settings.needsCapture && engine.capture.canChoose
    }
    @objc private func tintChanged(_ sender: NSSlider) {
        settings.tint = sender.doubleValue; tintLabel.stringValue = "Tint · \(Int((settings.tint*100).rounded()))%"
        engine.update(settings)
    }
    @objc private func selectWindow() { engine.choose(settings) }
    @objc private func stopAccess() { engine.stop() }
    @objc private func showWindow() { window.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true) }
    @objc private func privacyLimits() {
        let alert = NSAlert(); alert.messageText = "Local processing, experimental coverage"
        alert.informativeText = "The entire explicitly selected WhatsApp window can reach memory, even with sidebar-only blur. Apple's on-device OCR and rectangle detection estimate message and identity regions; they can miss or misclassify content, especially media, RTL, replies and changed layouts. No recognized text is stored, logged or transmitted.\n\nThis is a separate click-through processed image above WhatsApp. It can lag during scrolling; clicks still reach live WhatsApp and can miss the displayed target. Focus, occlusion, resizing, capture failure or quitting can remove it and expose original WhatsApp. It is not protection against screenshots, recording, sharing, or malicious software. No supported-layout or zero-frame disclosure guarantee is made.\n\nOnly ordinary foreground windows are test candidates. Use an English UI with Search and an empty message field visible. Other layouts may remain unblurred. Moving or resizing can require selecting the window again. Pausing stops capture; an already-running local request can finish, but its result is discarded. No automatic capture at launch or login."
        alert.addButton(withTitle: "Understood"); alert.runModal()
    }
    @objc private func quit() { engine.stop(); NSApp.terminate(nil) }
    func windowWillClose(_ notification: Notification) { engine.stop() }
    func applicationWillTerminate(_ notification: Notification) { engine.stop() }
}

import AppKit
import IntegrationCore
import CaptureAdapter

private final class SettingsStack: NSStackView { override var isFlipped: Bool { true } }

final class PreviewApp: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private var settings = BlurSettings()
    private let engine = AutomaticController()
    private let store = PreferenceStore()
    private var enabled = false
    private var preferenceError = false
    private var window: NSWindow!
    private var item: NSStatusItem!
    private var switches: [NSButton] = []
    private var hovers: [NSButton] = []
    private let tintLabel = NSTextField(labelWithString: "Tint · 65%")
    private let status = NSTextField(wrappingLabelWithString: "Paused · enable automatic mode to begin setup")
    private let choose = NSButton(title: "Enable / Resume automatic blur", target: nil, action: nil)
    func applicationDidFinishLaunching(_ notification: Notification) {
        do { let saved = try store.load();settings = saved.settings;enabled = saved.automaticEnabled }
        catch { preferenceError = true;enabled = false }
        window = NSWindow(contentRect: NSRect(x: 0,y: 0,width: 480,height: 760),styleMask: [.titled,.closable,.miniaturizable],backing: .buffered,defer: false)
        window.title = "WhatsApp Blur · " + (Bundle.main.object(forInfoDictionaryKey:"PrivacyBuildIdentifier") as? String ?? "unverified build")
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
        label("Automatic mode finds authenticated WhatsApp windows after Screen Recording permission. Detection remains experimental; test with invented messages before relying on it.")
        label("Messages",14,.semibold)
        for (index,title) in ["Blur sidebar message previews","Blur conversation messages"].enumerated() {
            let button = NSButton(checkboxWithTitle: title,target: self,action: #selector(changed(_:)))
            button.tag = index; button.state = (index == 0 ? settings.sidebarPreviews : settings.conversationMessages) ? .on : .off; switches.append(button); stack.addArrangedSubview(button)
            let hover = NSButton(checkboxWithTitle: "Reveal hovered \(index == 0 ? "preview" : "message") · up to 2 seconds",target: self,action: #selector(changed(_:)))
            hover.state = (index == 0 ? settings.sidebarHover : settings.conversationHover) ? .on : .off;hover.font = .systemFont(ofSize: 11); hover.tag = index; hovers.append(hover); stack.addArrangedSubview(hover)
        }
        label("Identity",14,.semibold)
        for (index,title) in ["Blur contact and group names","Blur avatars"].enumerated() {
            let button = NSButton(checkboxWithTitle: title,target: self,action: #selector(changed(_:)))
            button.tag = index+2;button.state = (index == 0 ? settings.names : settings.avatars) ? .on : .off; switches.append(button); stack.addArrangedSubview(button)
        }
        label("Names and avatars stay blurred during message hover. Detection is experimental, including identity placement.",11)
        tintLabel.stringValue = "Tint · \(Int((settings.tint*100).rounded()))%"
        stack.addArrangedSubview(tintLabel)
        let slider = NSSlider(value: settings.tint,minValue: 0.4,maxValue: 0.9,target: self,action: #selector(tintChanged(_:)))
        slider.widthAnchor.constraint(equalToConstant: 400).isActive = true; slider.isContinuous = false; stack.addArrangedSubview(slider)
        label("40% — 90% tint, over opaque Gaussian blur. No sharp-source transparency.",11)
        status.font = .systemFont(ofSize: 12,weight: .medium); status.textColor = .systemOrange
        status.preferredMaxLayoutWidth = 428; stack.addArrangedSubview(status)
        choose.target = self; choose.action = #selector(enableAutomatic); choose.bezelStyle = .rounded; stack.addArrangedSubview(choose)
        let actions = NSStackView(); actions.orientation = .horizontal; actions.spacing = 12
        actions.addArrangedSubview(NSButton(title: "Pause / stop access",target: self,action: #selector(stopAccess)))
        actions.addArrangedSubview(NSButton(title: "Privacy limits…",target: self,action: #selector(privacyLimits)))
        stack.addArrangedSubview(actions)
        label("Pixels and local OCR stay in memory. No network, telemetry, audio or Accessibility. Only blur preferences are saved locally. Closing settings keeps automatic mode running. Pause stops capture.",11)
        engine.onStatus = { [weak self] in self?.status.stringValue = $0 }
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(systemSymbolName: "eye.slash",accessibilityDescription: "WhatsApp Blur · experimental test")
        let menu = NSMenu()
        let open = NSMenuItem(title: "WhatsApp Blur · settings",action: #selector(showWindow),keyEquivalent: ""); open.target = self; menu.addItem(open)
        let stop = NSMenuItem(title: "Pause / stop window access",action: #selector(stopAccess),keyEquivalent: ""); stop.target = self; menu.addItem(stop)
        menu.addItem(.separator())
        let quit = NSMenuItem(title: "Quit",action: #selector(quit),keyEquivalent: "q"); quit.target = self; menu.addItem(quit); item.menu = menu
        let resume = NSMenuItem(title:"Enable / Resume automatic blur",action:#selector(enableAutomatic),keyEquivalent:"");resume.target = self;menu.insertItem(resume,at:1)
        window.center()
        engine.configure(enabled:enabled,settings:settings)
        if preferenceError { status.stringValue = "Preferences could not be read. Automatic capture is disabled. Review settings and Enable to save a new valid configuration." }
    }
    @objc private func changed(_ sender: NSButton) {
        settings.sidebarPreviews = switches[0].state == .on; settings.conversationMessages = switches[1].state == .on
        settings.names = switches[2].state == .on; settings.avatars = switches[3].state == .on
        settings.sidebarHover = hovers[0].state == .on; settings.conversationHover = hovers[1].state == .on
        hovers[0].isEnabled = settings.sidebarPreviews; hovers[1].isEnabled = settings.conversationMessages
        saveAndApply()
    }
    @objc private func tintChanged(_ sender: NSSlider) {
        settings.tint = sender.doubleValue; tintLabel.stringValue = "Tint · \(Int((settings.tint*100).rounded()))%"
        saveAndApply()
    }
    private func saveAndApply(explicitResume:Bool = false) {
        do { try store.save(AutoPreferences(automaticEnabled:enabled,settings:settings));preferenceError = false }
        catch { enabled = false;engine.configure(enabled:false,settings:settings);status.stringValue = "Could not save preferences. Capture stopped; the last saved state may remain. Check local storage before restarting.";return }
        engine.configure(enabled:enabled,settings:settings,explicitResume:explicitResume)
    }
    @objc private func enableAutomatic() {
        guard settings.needsCapture else { status.stringValue = "Choose at least one blur category first.";return }
        guard ScreenPermission.requestFromUserAction() else {
            status.stringValue = "Screen Recording permission is required. In System Settings → Privacy & Security → Screen Recording, allow WhatsApp Blur Automatic Beta; restart it if macOS asks, then Resume. The OS permission is broader than WhatsApp; this app captures only authenticated WhatsApp windows.";return
        }
        enabled = true;saveAndApply(explicitResume:true)
    }
    @objc private func stopAccess() { enabled = false;engine.configure(enabled:false,settings:settings);saveAndApply() }
    @objc private func showWindow() { window.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true) }
    @objc private func privacyLimits() {
        let alert = NSAlert(); alert.messageText = "Local processing, experimental coverage"
        alert.informativeText = "Automatic capture uses macOS Screen Recording permission. The OS grant is broader than WhatsApp; this app authenticates the official publisher and uses only independent WhatsApp window filters. Up to two windows fit the current resource limit. No display capture, audio, telemetry or network access. Only blur settings and enabled/paused state are saved. Pixels and local OCR stay in memory.\n\nThis is a separate click-through processed image. OCR can miss content or misidentify regions. It can lag live WhatsApp and clicks still reach that live window. Capture failure, layout changes, unsupported windows or quitting expose original content. Startup cannot protect WhatsApp before this app has permission, attached and rendered. Coverage and timing remain unverified; this beta is not ready for sensitive conversations.\n\nClosing settings keeps capture running. Pause stops it and saves disabled state. Quit stops capture but retains your enabled setting for your next launch. No login item is installed. Rebuilding an ad-hoc signed app may require macOS permission again."
        alert.addButton(withTitle: "Understood"); alert.runModal()
    }
    @objc private func quit() { engine.shutdown(); NSApp.terminate(nil) }
    func windowWillClose(_ notification: Notification) { /* Settings close never changes saved capture intent. */ }
    func applicationWillTerminate(_ notification: Notification) { engine.shutdown() }
}

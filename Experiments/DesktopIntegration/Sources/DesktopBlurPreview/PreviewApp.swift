import AppKit
import IntegrationCore
import CaptureAdapter

// A scoped-access checkpoint. It deliberately has no protected/active-blur state.
final class PreviewApp: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private var settings = BlurSettings()
    private let capture = SelectedWindowCapture()
    private var window: NSWindow!
    private var item: NSStatusItem!
    private var switches: [NSButton] = []
    private var tintSlider: NSSlider!
    private let tintLabel = NSTextField(labelWithString: "Tint 65%")
    private let status = NSTextField(wrappingLabelWithString: "No window selected. No blur is active.")
    private let choose = NSButton(title: "Test WhatsApp window access…", target: nil, action: nil)

    func applicationDidFinishLaunching(_ notification: Notification) {
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 490, height: 720),
                          styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
        window.title = "WhatsApp Blur — Integration Preview"
        window.isReleasedWhenClosed = false; window.delegate = self
        let stack = NSStackView(); stack.orientation = .vertical; stack.alignment = .leading; stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        let root = NSView(); root.addSubview(stack); window.contentView = root
        NSLayoutConstraint.activate([stack.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -24),
            stack.topAnchor.constraint(equalTo: root.topAnchor, constant: 24)])
        let heading = NSTextField(labelWithString: "Desktop integration checkpoint")
        heading.font = .systemFont(ofSize: 21, weight: .semibold); stack.addArrangedSubview(heading)
        let warning = NSTextField(wrappingLabelWithString: "Message detection and real-window blur are not available yet. This build tests access to one window you select. WhatsApp stays visible and unprotected.")
        warning.textColor = .secondaryLabelColor; stack.addArrangedSubview(warning)
        let planned = NSTextField(labelWithString: "Requested blur settings · not applied in this checkpoint")
        planned.font = .systemFont(ofSize: 12, weight: .semibold); stack.addArrangedSubview(planned)
        for (index, title) in ["Blur sidebar previews", "Blur conversation messages", "Blur names", "Blur avatars"].enumerated() {
            let button = NSButton(checkboxWithTitle: title, target: self, action: #selector(changed(_:)))
            button.tag = index; button.state = index < 2 ? .on : .off; switches.append(button); stack.addArrangedSubview(button)
        }
        let identity = NSTextField(wrappingLabelWithString: "Name/avatar blur is planned for the sidebar and chat header. Identity stays blurred during message hover when enabled.")
        identity.font = .systemFont(ofSize: 11); identity.textColor = .secondaryLabelColor; stack.addArrangedSubview(identity)
        let hover = NSTextField(labelWithString: "Per-message hover reveal: pending real-window validation")
        hover.textColor = .secondaryLabelColor; hover.font = .systemFont(ofSize: 11); stack.addArrangedSubview(hover)
        tintSlider = NSSlider(value: 0.65, minValue: 0.4, maxValue: 0.9, target: self, action: #selector(tintChanged(_:)))
        tintSlider.widthAnchor.constraint(equalToConstant: 310).isActive = true
        stack.addArrangedSubview(tintLabel); stack.addArrangedSubview(tintSlider)
        stack.addArrangedSubview(status)
        status.font = .systemFont(ofSize: 12, weight: .medium)
        choose.target = self; choose.action = #selector(selectWindow); stack.addArrangedSubview(choose)
        let stop = NSButton(title: "Stop window access", target: self, action: #selector(stopAccess)); stack.addArrangedSubview(stop)
        let boundary = NSTextField(wrappingLabelWithString: "Accepts one test frame, checks metadata, then stops. No image is displayed or saved. Capture may include the entire selected window, regardless of planned blur settings. Everything stays local; settings reset on quit.")
        boundary.font = .systemFont(ofSize: 11); boundary.textColor = .secondaryLabelColor; stack.addArrangedSubview(boundary)
        capture.onStatus = { [weak self] text, busy in
            guard let self = self else { return }
            self.status.stringValue = text; self.choose.isEnabled = !busy && self.settings.needsCapture
        }
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(systemSymbolName: "exclamationmark.shield", accessibilityDescription: "Integration preview — no blur active")
        let menu = NSMenu()
        let open = NSMenuItem(title: "Show integration preview", action: #selector(showWindow), keyEquivalent: ""); open.target = self; menu.addItem(open)
        let stopItem = NSMenuItem(title: "Stop window access", action: #selector(stopAccess), keyEquivalent: ""); stopItem.target = self; menu.addItem(stopItem)
        menu.addItem(.separator())
        let quit = NSMenuItem(title: "Quit preview", action: #selector(quit), keyEquivalent: "q"); quit.target = self; menu.addItem(quit)
        item.menu = menu
        window.center(); showWindow()
    }
    @objc private func changed(_ sender: NSButton) {
        capture.stop(message: "Settings updated for future blur. No window access or blur is active.")
        settings.sidebarPreviews = switches[0].state == .on
        settings.conversationMessages = switches[1].state == .on
        settings.names = switches[2].state == .on
        settings.avatars = switches[3].state == .on
        // Do not reenable selection while an old asynchronous stream is retiring.
        choose.isEnabled = settings.needsCapture && capture.canChoose
    }
    @objc private func tintChanged(_ sender: NSSlider) {
        settings.tint = sender.doubleValue
        tintLabel.stringValue = "Tint \(Int((settings.tint * 100).rounded()))%"
    }
    @objc private func selectWindow() { capture.choose(settings: settings) }
    @objc private func stopAccess() { capture.stop() }
    @objc private func showWindow() { window.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true) }
    @objc private func quit() { capture.stop(); NSApp.terminate(nil) }
    func windowWillClose(_ notification: Notification) { capture.stop() }
    func applicationWillTerminate(_ notification: Notification) { capture.stop() }
}

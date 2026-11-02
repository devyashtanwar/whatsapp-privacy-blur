import AppKit

final class StatusBarController: NSObject, NSMenuDelegate {
    private var statusItem: NSStatusItem?
    private let menu = NSMenu()
    private var status = "Waiting for WhatsApp"
    private var statusLine: NSMenuItem?
    private var diagnostic: String?
    var onRetryAuthentication: (() -> Void)?

    func setup() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem?.button?.image = NSImage(systemSymbolName: "eye.slash.fill",
                                           accessibilityDescription: "WhatsApp Privacy Cover")
        menu.delegate = self
        statusItem?.menu = menu
        rebuildMenu()
    }

    func setStatus(_ value: String, diagnostic: String?) {
        self.diagnostic = diagnostic
        status = value
        statusLine?.title = value
        let symbol = diagnostic != nil ? "exclamationmark.shield" : (Settings.shared.overlayEnabled ? "eye.slash.fill" : "eye.fill")
        statusItem?.button?.image = NSImage(systemSymbolName: symbol,
                                           accessibilityDescription: value)
    }

    func menuWillOpen(_ menu: NSMenu) { rebuildMenu() }

    private func add(_ title: String, action: Selector, checked: Bool, key: String = "") {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        item.state = checked ? .on : .off
        menu.addItem(item)
    }

    private func rebuildMenu() {
        menu.removeAllItems()
        let title = NSMenuItem(title: "WhatsApp Privacy Cover", action: nil, keyEquivalent: "")
        title.isEnabled = false
        menu.addItem(title)
        let line = NSMenuItem(title: status, action: nil, keyEquivalent: "")
        line.isEnabled = false
        statusLine = line
        menu.addItem(line)
        if diagnostic != nil {
            let details = NSMenuItem(title: "Authentication details…", action: #selector(showAuthenticationDetails), keyEquivalent: "")
            details.target = self
            menu.addItem(details)
        }
        let retry = NSMenuItem(title: "Retry WhatsApp authentication", action: #selector(retryAuthentication), keyEquivalent: "")
        retry.target = self
        menu.addItem(retry)
        menu.addItem(.separator())
        add("Enabled", action: #selector(toggleEnabled), checked: Settings.shared.overlayEnabled, key: "e")
        add("Cover entire window", action: #selector(toggleFullWindow), checked: Settings.shared.fullWindow)
        add("Hover to reveal window", action: #selector(toggleHover), checked: Settings.shared.hoverReveal)

        let container = NSView(frame: NSRect(x: 0, y: 0, width: 240, height: 50))
        let label = NSTextField(labelWithString: "Sidebar width: \(Int(Settings.shared.overlayWidth))")
        label.frame = NSRect(x: 20, y: 27, width: 200, height: 18)
        label.textColor = Settings.shared.fullWindow ? .tertiaryLabelColor : .labelColor
        container.addSubview(label)
        let slider = NSSlider(value: Double(Settings.shared.overlayWidth), minValue: 200, maxValue: 500,
                              target: self, action: #selector(widthChanged(_:)))
        slider.frame = NSRect(x: 20, y: 3, width: 200, height: 20)
        slider.isEnabled = !Settings.shared.fullWindow
        slider.isContinuous = false
        container.addSubview(slider)
        let sliderItem = NSMenuItem()
        sliderItem.view = container
        menu.addItem(sliderItem)
        menu.addItem(.separator())
        add("Launch at Login", action: #selector(toggleLogin), checked: LaunchAtLogin.isEnabled)
        let limitations = NSMenuItem(title: "Privacy limits…", action: #selector(showLimits), keyEquivalent: "")
        limitations.target = self
        menu.addItem(limitations)
        menu.addItem(.separator())
        let quit = NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)
    }

    @objc private func retryAuthentication() { onRetryAuthentication?() }
    @objc private func showAuthenticationDetails() {
        guard let diagnostic = diagnostic else { return }
        let alert = NSAlert()
        alert.messageText = "WhatsApp cover is inactive"
        alert.informativeText = diagnostic
        alert.runModal()
    }
    @objc private func toggleEnabled() { Settings.shared.overlayEnabled.toggle() }
    @objc private func toggleFullWindow() { Settings.shared.fullWindow.toggle() }
    @objc private func toggleHover() { Settings.shared.hoverReveal.toggle() }
    @objc private func widthChanged(_ sender: NSSlider) { Settings.shared.overlayWidth = CGFloat(sender.doubleValue) }
    @objc private func toggleLogin() {
        do { try LaunchAtLogin.setEnabled(!LaunchAtLogin.isEnabled) }
        catch {
            let alert = NSAlert()
            alert.messageText = "Could not change Launch at Login"
            alert.informativeText = error.localizedDescription
            alert.runModal()
        }
    }
    @objc private func showLimits() {
        let alert = NSAlert()
        alert.messageText = "A visual cover, not an app lock"
        alert.informativeText = "No screenshots, Accessibility access, or network access are needed. Covers can lag during window changes and disappear if the app exits. Hover reveal exposes the window when enabled. Notifications, previews, and captures of WhatsApp itself are not protected. Do not rely on this app to redact screen sharing."
        alert.runModal()
    }
    @objc private func quit() { NSApp.terminate(nil) }
}

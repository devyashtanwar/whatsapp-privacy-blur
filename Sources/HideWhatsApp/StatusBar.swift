import AppKit

final class StatusBarController {
    private var statusItem: NSStatusItem?
    private let menu = NSMenu()
    private var enabledItem: NSMenuItem!
    private var autoDetectItem: NSMenuItem!
    private var widthSliderItem: NSMenuItem!
    private var widthSlider: NSSlider!
    private var widthLabel: NSTextField!
    private var blurIntensityMenu: NSMenu!
    private var launchAtLoginItem: NSMenuItem!

    func setup() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        guard let button = statusItem?.button else { return }
        button.image = NSImage(systemSymbolName: "eye.slash.fill", accessibilityDescription: "Hide WhatsApp")

        buildMenu()
        statusItem?.menu = menu
    }

    private func buildMenu() {
        // Title
        let titleItem = NSMenuItem(title: "WhatsApp Privacy Blur", action: nil, keyEquivalent: "")
        titleItem.isEnabled = false
        menu.addItem(titleItem)

        menu.addItem(NSMenuItem.separator())

        // Enable/Disable toggle
        enabledItem = NSMenuItem(
            title: "Enabled",
            action: #selector(toggleEnabled),
            keyEquivalent: "e"
        )
        enabledItem.target = self
        enabledItem.state = Settings.shared.overlayEnabled ? .on : .off
        menu.addItem(enabledItem)

        menu.addItem(NSMenuItem.separator())

        // Auto-detect width checkbox
        autoDetectItem = NSMenuItem(
            title: "Auto-detect Width",
            action: #selector(toggleAutoDetect),
            keyEquivalent: ""
        )
        autoDetectItem.target = self
        autoDetectItem.state = Settings.shared.autoDetectWidth ? .on : .off
        menu.addItem(autoDetectItem)

        // Width slider
        widthSliderItem = createWidthSliderItem()
        menu.addItem(widthSliderItem)
        updateSliderState()

        menu.addItem(NSMenuItem.separator())

        // Blur intensity submenu
        let blurIntensityItem = NSMenuItem(title: "Blur Intensity", action: nil, keyEquivalent: "")
        blurIntensityMenu = NSMenu()
        blurIntensityItem.submenu = blurIntensityMenu

        for (value, title) in [("light", "Light"), ("medium", "Medium"), ("heavy", "Heavy")] {
            let item = NSMenuItem(title: title, action: #selector(setBlurIntensity(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = value
            item.state = Settings.shared.blurIntensity == value ? .on : .off
            blurIntensityMenu.addItem(item)
        }
        menu.addItem(blurIntensityItem)

        menu.addItem(NSMenuItem.separator())

        // Launch at Login
        launchAtLoginItem = NSMenuItem(
            title: "Launch at Login",
            action: #selector(toggleLaunchAtLogin),
            keyEquivalent: ""
        )
        launchAtLoginItem.target = self
        launchAtLoginItem.state = LaunchAtLogin.isEnabled ? .on : .off
        menu.addItem(launchAtLoginItem)

        menu.addItem(NSMenuItem.separator())

        // Quit
        let quitItem = NSMenuItem(
            title: "Quit",
            action: #selector(quit),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)
    }

    private func createWidthSliderItem() -> NSMenuItem {
        let containerView = NSView(frame: NSRect(x: 0, y: 0, width: 200, height: 50))

        // Label
        widthLabel = NSTextField(labelWithString: "Width: \(Int(Settings.shared.overlayWidth))px")
        widthLabel.frame = NSRect(x: 20, y: 28, width: 160, height: 16)
        widthLabel.font = .systemFont(ofSize: 12)
        containerView.addSubview(widthLabel)

        // Slider
        widthSlider = NSSlider(value: Double(Settings.shared.overlayWidth), minValue: 200, maxValue: 500, target: self, action: #selector(widthChanged))
        widthSlider.frame = NSRect(x: 20, y: 4, width: 160, height: 20)
        widthSlider.isContinuous = true
        containerView.addSubview(widthSlider)

        let item = NSMenuItem()
        item.view = containerView
        return item
    }

    private func updateSliderState() {
        let isManual = !Settings.shared.autoDetectWidth
        widthSlider.isEnabled = isManual
        widthLabel.textColor = isManual ? .labelColor : .tertiaryLabelColor
    }

    @objc private func toggleEnabled() {
        Settings.shared.overlayEnabled.toggle()
        enabledItem.state = Settings.shared.overlayEnabled ? .on : .off

        if let button = statusItem?.button {
            let iconName = Settings.shared.overlayEnabled ? "eye.slash.fill" : "eye.fill"
            button.image = NSImage(systemSymbolName: iconName, accessibilityDescription: "Hide WhatsApp")
        }
    }

    @objc private func toggleAutoDetect() {
        Settings.shared.autoDetectWidth.toggle()
        autoDetectItem.state = Settings.shared.autoDetectWidth ? .on : .off
        updateSliderState()
    }

    @objc private func widthChanged() {
        let width = CGFloat(widthSlider.integerValue)
        Settings.shared.overlayWidth = width
        widthLabel.stringValue = "Width: \(Int(width))px"
    }

    @objc private func setBlurIntensity(_ sender: NSMenuItem) {
        guard let value = sender.representedObject as? String else { return }
        Settings.shared.blurIntensity = value

        for item in blurIntensityMenu.items {
            item.state = (item.representedObject as? String) == value ? .on : .off
        }
    }

    @objc private func toggleLaunchAtLogin() {
        Settings.shared.launchAtLogin.toggle()
        launchAtLoginItem.state = LaunchAtLogin.isEnabled ? .on : .off
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }
}

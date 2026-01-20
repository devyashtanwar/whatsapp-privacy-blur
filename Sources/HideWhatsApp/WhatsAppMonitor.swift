import AppKit
import ApplicationServices

final class WhatsAppMonitor {
    private let sidebarOverlay: BlurOverlayWindow
    private let headerOverlay: BlurOverlayWindow
    private var pollTimer: Timer?
    private var isWhatsAppActive = false

    private let whatsAppBundleID = "net.whatsapp.WhatsApp"
    private let headerHeight: CGFloat = 60

    init(sidebarOverlay: BlurOverlayWindow, headerOverlay: BlurOverlayWindow) {
        self.sidebarOverlay = sidebarOverlay
        self.headerOverlay = headerOverlay
        setupObservers()
        checkInitialState()
    }

    private func setupObservers() {
        let nc = NSWorkspace.shared.notificationCenter

        nc.addObserver(
            self,
            selector: #selector(appDidActivate),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )

        nc.addObserver(
            self,
            selector: #selector(appDidDeactivate),
            name: NSWorkspace.didDeactivateApplicationNotification,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(settingsChanged),
            name: .settingsChanged,
            object: nil
        )
    }

    private func checkInitialState() {
        if let frontApp = NSWorkspace.shared.frontmostApplication,
           frontApp.bundleIdentifier == whatsAppBundleID {
            activateOverlay()
        }
    }

    @objc private func appDidActivate(_ notification: Notification) {
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
              app.bundleIdentifier == whatsAppBundleID else {
            return
        }
        activateOverlay()
    }

    @objc private func appDidDeactivate(_ notification: Notification) {
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
              app.bundleIdentifier == whatsAppBundleID else {
            return
        }
        deactivateOverlay()
    }

    @objc private func settingsChanged() {
        sidebarOverlay.updateBlurIntensity()
        headerOverlay.updateBlurIntensity()

        if Settings.shared.overlayEnabled && isWhatsAppActive {
            updateOverlayPosition()
        } else if !Settings.shared.overlayEnabled {
            sidebarOverlay.hide()
            headerOverlay.hide()
        }
    }

    private func activateOverlay() {
        guard Settings.shared.overlayEnabled else { return }
        isWhatsAppActive = true
        startPolling()
        updateOverlayPosition()
        sidebarOverlay.show()
        headerOverlay.show()
    }

    private func deactivateOverlay() {
        isWhatsAppActive = false
        stopPolling()
        sidebarOverlay.hide()
        headerOverlay.hide()
    }

    private func startPolling() {
        pollTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.updateOverlayPosition()
        }
    }

    private func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
    }

    private func updateOverlayPosition() {
        guard let whatsAppWindow = findWhatsAppWindow() else {
            sidebarOverlay.hide()
            headerOverlay.hide()
            return
        }

        let sidebarWidth = calculateSidebarWidth(from: whatsAppWindow)
        let sidebarFrame = NSRect(
            x: whatsAppWindow.origin.x,
            y: whatsAppWindow.origin.y,
            width: min(sidebarWidth, whatsAppWindow.width),
            height: whatsAppWindow.height
        )

        let headerFrame = NSRect(
            x: whatsAppWindow.origin.x + sidebarWidth,
            y: whatsAppWindow.maxY - headerHeight,
            width: whatsAppWindow.width - sidebarWidth,
            height: headerHeight
        )

        sidebarOverlay.updateFrame(sidebarFrame)
        headerOverlay.updateFrame(headerFrame)

        if Settings.shared.overlayEnabled && isWhatsAppActive {
            sidebarOverlay.show()
            headerOverlay.show()
        }
    }

    private func findWhatsAppWindow() -> NSRect? {
        guard let app = NSWorkspace.shared.runningApplications.first(where: {
            $0.bundleIdentifier == whatsAppBundleID
        }) else {
            return nil
        }

        let windowList = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []

        for window in windowList {
            guard let ownerPID = window[kCGWindowOwnerPID as String] as? Int32,
                  ownerPID == app.processIdentifier,
                  let bounds = window[kCGWindowBounds as String] as? [String: CGFloat],
                  let layer = window[kCGWindowLayer as String] as? Int,
                  layer == 0 else {
                continue
            }

            let x = bounds["X"] ?? 0
            let y = bounds["Y"] ?? 0
            let width = bounds["Width"] ?? 0
            let height = bounds["Height"] ?? 0

            let screenHeight = NSScreen.main?.frame.height ?? 0
            let flippedY = screenHeight - y - height

            return NSRect(x: x, y: flippedY, width: width, height: height)
        }

        return nil
    }

    private func calculateSidebarWidth(from windowFrame: NSRect) -> CGFloat {
        if Settings.shared.autoDetectWidth {
            return detectSidebarWidth(windowFrame: windowFrame) ?? (windowFrame.width * 0.30)
        } else {
            return Settings.shared.overlayWidth
        }
    }

    private func detectSidebarWidth(windowFrame: NSRect) -> CGFloat? {
        guard let app = NSWorkspace.shared.runningApplications.first(where: {
            $0.bundleIdentifier == whatsAppBundleID
        }) else {
            return nil
        }

        let axApp = AXUIElementCreateApplication(app.processIdentifier)

        var windowsRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(axApp, kAXWindowsAttribute as CFString, &windowsRef) == .success,
              let windows = windowsRef as? [AXUIElement],
              let mainWindow = windows.first else {
            return nil
        }

        if let sidebarWidth = findSidebarWidth(in: mainWindow) {
            return sidebarWidth
        }

        return windowFrame.width * 0.30
    }

    private func findSidebarWidth(in element: AXUIElement) -> CGFloat? {
        var childrenRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &childrenRef) == .success,
              let children = childrenRef as? [AXUIElement] else {
            return nil
        }

        for child in children {
            var roleRef: CFTypeRef?
            AXUIElementCopyAttributeValue(child, kAXRoleAttribute as CFString, &roleRef)

            if let role = roleRef as? String {
                if role == "AXSplitGroup" || role == "AXGroup" {
                    var subChildrenRef: CFTypeRef?
                    if AXUIElementCopyAttributeValue(child, kAXChildrenAttribute as CFString, &subChildrenRef) == .success,
                       let subChildren = subChildrenRef as? [AXUIElement],
                       let firstChild = subChildren.first {
                        var sizeRef: CFTypeRef?
                        if AXUIElementCopyAttributeValue(firstChild, kAXSizeAttribute as CFString, &sizeRef) == .success {
                            var size = CGSize.zero
                            AXValueGetValue(sizeRef as! AXValue, .cgSize, &size)
                            if size.width > 100 && size.width < 600 {
                                return size.width
                            }
                        }
                    }
                }
            }

            if let width = findSidebarWidth(in: child) {
                return width
            }
        }

        return nil
    }

    func checkAccessibilityPermission() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    deinit {
        stopPolling()
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        NotificationCenter.default.removeObserver(self)
    }
}

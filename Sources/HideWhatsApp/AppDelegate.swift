import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let statusBar = StatusBarController()
    private var sidebarOverlay: BlurOverlayWindow!
    private var headerOverlay: BlurOverlayWindow!
    private var monitor: WhatsAppMonitor!

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide dock icon
        NSApp.setActivationPolicy(.accessory)

        // Setup components
        statusBar.setup()
        sidebarOverlay = BlurOverlayWindow()
        headerOverlay = BlurOverlayWindow()
        monitor = WhatsAppMonitor(sidebarOverlay: sidebarOverlay, headerOverlay: headerOverlay)

        // Check accessibility permission
        if !monitor.checkAccessibilityPermission() {
            showAccessibilityAlert()
        }
    }

    private func showAccessibilityAlert() {
        let alert = NSAlert()
        alert.messageText = "Accessibility Permission Required"
        alert.informativeText = "WhatsApp Privacy Blur needs accessibility permission to detect WhatsApp's window position.\n\nPlease grant permission in System Settings > Privacy & Security > Accessibility."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Open Settings")
        alert.addButton(withTitle: "Later")

        if alert.runModal() == .alertFirstButtonReturn {
            let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
            NSWorkspace.shared.open(url)
        }
    }
}

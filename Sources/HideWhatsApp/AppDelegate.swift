import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let statusBar = StatusBarController()
    private let monitor = PrivacyMonitor()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        statusBar.setup()
        monitor.onStatusChange = { [weak self] status in self?.statusBar.setStatus(status) }
        monitor.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        monitor.stop()
    }
}

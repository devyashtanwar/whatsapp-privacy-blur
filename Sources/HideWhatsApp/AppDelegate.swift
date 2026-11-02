import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let statusBar = StatusBarController()
    private var monitor: PrivacyMonitor?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        guard RuntimeConfinement.isAllowed() else {
            let alert = NSAlert()
            alert.messageText = "Privacy confinement could not be verified"
            alert.informativeText = "Use the verified, sandboxed app bundle. Monitoring has not started. This app will not request additional permissions or use an unrestricted fallback."
            alert.runModal()
            NSApp.terminate(nil)
            return
        }
        statusBar.setup()
        let monitor = PrivacyMonitor(confinementAllowed: true)
        self.monitor = monitor
        monitor.onStatusChange = { [weak self] status, diagnostic in self?.statusBar.setStatus(status, diagnostic: diagnostic) }
        statusBar.onRetryAuthentication = { [weak monitor] in monitor?.retryAuthentication() }
        monitor.start()
    }
    func applicationWillTerminate(_ notification: Notification) { monitor?.stop() }
}

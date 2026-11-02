import AppKit
import PrivacyCore

/// Main-thread adapter: one timer, never a capture timer or global event tap.
final class PrivacyMonitor {
    private let renderer = CoverRenderer()
    private lazy var source = WindowMetadataSource(coverTarget: { [weak self] number in
        self?.renderer.targetWindow(for: number)
    })
    private lazy var coordinator = PrivacyCoordinator(source: source, sink: renderer)
    private var timer: Timer?
    private var observers: [(NotificationCenter, NSObjectProtocol)] = []
    private var screenAsleep = false
    private var sessionInactive = false
    private var status = ""
    var onStatusChange: ((String) -> Void)?

    func start() {
        guard observers.isEmpty else { return }
        let workspace = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.didLaunchApplicationNotification, NSWorkspace.didTerminateApplicationNotification,
                     NSWorkspace.didActivateApplicationNotification, NSWorkspace.didHideApplicationNotification,
                     NSWorkspace.didUnhideApplicationNotification, NSWorkspace.activeSpaceDidChangeNotification] {
            observe(workspace, name) { [weak self] in self?.synchronize() }
        }
        observe(workspace, NSWorkspace.screensDidSleepNotification) { [weak self] in
            self?.screenAsleep = true; self?.synchronize()
        }
        observe(workspace, NSWorkspace.screensDidWakeNotification) { [weak self] in
            self?.screenAsleep = false; self?.synchronize()
        }
        observe(workspace, NSWorkspace.sessionDidResignActiveNotification) { [weak self] in
            self?.sessionInactive = true; self?.synchronize()
        }
        observe(workspace, NSWorkspace.sessionDidBecomeActiveNotification) { [weak self] in
            self?.sessionInactive = false; self?.synchronize()
        }
        observe(.default, .settingsChanged) { [weak self] in self?.synchronize() }
        observe(.default, NSApplication.didChangeScreenParametersNotification) { [weak self] in self?.synchronize() }
        synchronize()
    }

    private func observe(_ center: NotificationCenter, _ name: Notification.Name, action: @escaping () -> Void) {
        let token = center.addObserver(forName: name, object: nil, queue: .main) { _ in action() }
        observers.append((center, token))
    }

    private func synchronize() {
        precondition(Thread.isMainThread)
        coordinator.update(configuration: Settings.shared.configuration,
                           targetRunning: !WindowMetadataSource.targetApplications.isEmpty,
                           suspended: screenAsleep || sessionInactive)
        if coordinator.isMonitoring && timer == nil {
            let next = Timer(timeInterval: 0.1, repeats: true) { [weak self] _ in
                self?.coordinator.poll()
                self?.updateStatus()
            }
            next.tolerance = 0.02
            RunLoop.main.add(next, forMode: .common)
            timer = next
        } else if !coordinator.isMonitoring {
            timer?.invalidate()
            timer = nil
        }
        updateStatus()
    }

    private func updateStatus() {
        let next: String
        if !Settings.shared.overlayEnabled { next = "Disabled — monitoring stopped" }
        else if screenAsleep || sessionInactive { next = "Paused" }
        else if renderer.trackedWindowCount == 0 { next = "Waiting for visible WhatsApp windows" }
        else { next = "Tracking \(renderer.trackedWindowCount) WhatsApp window(s)" }
        if status != next { status = next; onStatusChange?(next) }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        observers.forEach { $0.0.removeObserver($0.1) }
        observers.removeAll()
        coordinator.update(configuration: .init(enabled: false), targetRunning: false, suspended: true)
    }

    deinit {
        timer?.invalidate()
        observers.forEach { $0.0.removeObserver($0.1) }
    }
}

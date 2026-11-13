import AppKit
import CaptureAdapter
import IntegrationCore

/// Main-thread composition. No caller-supplied windows, image export or hidden service.
final class AutomaticController {
    var onStatus:((String)->Void)?
    private let discovery = WhatsAppDiscovery()
    private let attachment = AutomaticAttachment()
    private var enabled = false
    private var settings = BlurSettings()
    private var availability = RuntimeAvailability(sessionActive:false,screenAwake:false)
    private var awake:Bool { availability.canCapture }
    private var epoch:UInt64 = 0
    private var scanning = false
    private var scanDeadline:Double = 0
    private var timedOut = false
    private var nextScan:Double = 0
    private var delayedWindows = 0
    private var engines:[CaptureTarget:IntegrationCoordinator] = [:]
    private var retiring:[CaptureTarget:IntegrationCoordinator] = [:]
    private var pending:[CaptureTarget:DiscoveredWhatsAppWindow] = [:]
    private var statuses:[CaptureTarget:String] = [:]
    private var observers:[NSObjectProtocol] = []
    private var screenObserver:NSObjectProtocol?
    private var clock:Timer?
    private var partial = false
    static func makeEngine(settings:BlurSettings) -> IntegrationCoordinator { IntegrationCoordinator(settings:settings) }
    init() {
        let session = CGSessionCopyCurrentDictionary() as? [String:Any]
        availability = RuntimeAvailability(sessionActive:(session?[kCGSessionOnConsoleKey as String] as? Bool) == true && (session?[kCGSessionLoginDoneKey as String] as? Bool) == true,
                                           screenAwake:CGDisplayIsAsleep(CGMainDisplayID()) == 0)
        let center = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.didLaunchApplicationNotification,NSWorkspace.didTerminateApplicationNotification,NSWorkspace.didActivateApplicationNotification] {
            observers.append(center.addObserver(forName:name,object:nil,queue:.main) { [weak self] _ in self?.schedule() })
        }
        for (name,value) in [(NSWorkspace.sessionDidResignActiveNotification,false),(NSWorkspace.sessionDidBecomeActiveNotification,true)] {
            observers.append(center.addObserver(forName:name,object:nil,queue:.main) { [weak self] _ in
                guard let self = self else { return };self.availability.sessionChanged(value);self.availabilityChanged()
            })
        }
        for (name,value) in [(NSWorkspace.screensDidSleepNotification,false),(NSWorkspace.screensDidWakeNotification,true)] {
            observers.append(center.addObserver(forName:name,object:nil,queue:.main) { [weak self] _ in
                guard let self = self else { return };self.availability.screenChanged(value);self.availabilityChanged()
            })
        }
        screenObserver = NotificationCenter.default.addObserver(forName:NSApplication.didChangeScreenParametersNotification,object:nil,queue:.main) { [weak self] _ in
            guard let self = self else { return };self.retireAll();self.schedule()
        }
        let timer = Timer(timeInterval:0.1,repeats:true) { [weak self] _ in self?.tick() }
        clock = timer;RunLoop.main.add(timer,forMode:.common)
    }
    func configure(enabled:Bool,settings:BlurSettings,explicitResume:Bool = false) {
        precondition(Thread.isMainThread)
        self.enabled = enabled;self.settings = settings;epoch &+= 1
        if explicitResume { attachment.resetFailures();timedOut = false }
        if !enabled || !settings.needsCapture { retireAll();onStatus?(enabled ? "All blur categories are off. No capture." : "Paused. WhatsApp is visible.");return }
        for engine in engines.values { engine.update(settings) }
        nextScan = 0;tick()
    }
    func shutdown() { enabled = false;epoch &+= 1;retireAll();clock?.invalidate() }
    private var now:Double { ProcessInfo.processInfo.systemUptime }
    private func schedule() { nextScan = min(nextScan,now+0.1) }
    private func availabilityChanged() {
        epoch &+= 1
        if !awake { retireAll();onStatus?("Session inactive. Capture stopped.") }
        else { nextScan = 0 }
    }
    private func retire(_ key:CaptureTarget) {
        guard let engine = engines.removeValue(forKey:key) else { return }
        statuses.removeValue(forKey:key);retiring[key] = engine;engine.stop()
    }
    private func retireAll() {
        pending.removeAll()
        for key in Array(engines.keys) { retire(key) }
        _ = attachment.reconcile(enabled:false,permission:false,awake:false,targets:[],now:now)
    }
    private func tick() {
        for (key,engine) in retiring where engine.capture.canChoose { retiring.removeValue(forKey:key) }
        guard enabled,settings.needsCapture,awake else { return }
        guard ScreenPermission.preflight() else {
            epoch &+= 1;retireAll();onStatus?("Screen Recording permission required. Enable it in setup; then Resume. No capture.");return
        }
        if scanning && now > scanDeadline { timedOut = true;epoch &+= 1;retireAll();onStatus?("Window discovery timed out. No blur. Restart the beta to retry.") }
        guard !timedOut else { return }
        if retiring.isEmpty { startPending() }
        guard now >= nextScan,!scanning else { return }
        scanning = true;scanDeadline = now+10;nextScan = now+1
        let revision = epoch
        let accepted = discovery.scan { [weak self] result in
            guard let self = self else { return };self.scanning = false
            guard revision == self.epoch,self.enabled,self.awake,self.settings.needsCapture else { return }
            self.accept(result)
        }
        if !accepted { scanning = false;timedOut = true;onStatus?("Window discovery is still pending. Restart the beta to retry.") }
    }
    private func accept(_ result:DiscoveryResult) {
        switch result {
        case .permissionRequired: retireAll();onStatus?("Screen Recording permission required. No blur is active.")
        case .untrusted: retireAll();onStatus?("WhatsApp publisher could not be authenticated. No capture; use an official installation.")
        case .failed: retireAll();onStatus?("Window discovery failed. Check permission and Resume; no blur is active.");timedOut = true
        case .absent: retireAll();delayedWindows = 0;onStatus?("Waiting for WhatsApp. Automatic mode is enabled.")
        case .windows(let windows,let unsupported):
            let changes = attachment.reconcile(enabled:enabled,permission:true,awake:awake,targets:windows.map(\.candidate),now:now)
            partial = changes.partial || unsupported
            for key in changes.stop { retire(key);pending.removeValue(forKey:key) }
            for c in changes.start { pending[c.target] = windows.first { $0.candidate == c } }
            if retiring.isEmpty { startPending() }
            if windows.isEmpty {
                let waits = [0.1,0.25,0.5,1.0];nextScan = now+waits[min(delayedWindows,3)];delayedWindows = min(delayedWindows+1,3)
                onStatus?(unsupported ? "WhatsApp window exceeds the current size limit. No blur is active." : "WhatsApp is running. Waiting for a supported visible window; no blur yet.")
            } else { delayedWindows = 0;report() }
        }
    }
    private func startPending() {
        guard retiring.isEmpty,enabled,settings.needsCapture,awake,ScreenPermission.preflight() else { return }
        for (key,target) in pending {
            guard engines[key] == nil,engines.count < 2 else { continue }
            let engine = Self.makeEngine(settings:settings);engines[key] = engine
            engine.onStatus = { [weak self] text in self?.statuses[key] = text;self?.report() }
            engine.capture.onStatus = { [weak self] text,_ in self?.statuses[key] = text;self?.report() }
            engine.onCaptureStopped = { [weak self,weak engine] reason in
                guard let self = self,let engine = engine,self.engines[key] === engine else { return }
                self.engines.removeValue(forKey:key);self.retiring[key] = engine;self.statuses.removeValue(forKey:key)
                let permanent = reason == .security || reason == .permission || reason == .explicit
                if reason != .geometry && reason != .session { self.attachment.failed(key,permanent:permanent,now:self.now) }
                else { self.attachment.retiredForGeometry(key) }
                self.nextScan = self.now+0.25;self.onStatus?(permanent ? "Window access rejected. No blur for this window; check permission or publisher, then Resume." : "Reconnecting WhatsApp window. Original content may be visible.")
            }
            statuses[key] = "Starting authenticated window capture. Coverage unverified."
            AutomaticWindowCapture.start(target,capture:engine.capture,settings:settings)
            pending.removeValue(forKey:key)
        }
    }
    private func report() {
        let details = statuses.sorted { $0.key.windowID < $1.key.windowID }.map(\.value).joined(separator:"\n")
        onStatus?((partial ? "Partial: some windows exceed the current limit or await retry.\n" : "") + (details.isEmpty ? "No current rendering. Coverage unverified." : details))
    }
    deinit {
        clock?.invalidate()
        for observer in observers { NSWorkspace.shared.notificationCenter.removeObserver(observer) }
        if let observer = screenObserver { NotificationCenter.default.removeObserver(observer) }
    }
}

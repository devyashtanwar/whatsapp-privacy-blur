import AppKit
import ScreenCaptureKit
import CoreMedia
import CoreVideo
import IntegrationCore
import PrivacyCore

/// The first integration gate accepts one complete selected-window frame for metadata validation.
/// It reads frame metadata only; never renders, saves or logs the image or window title.
public final class SelectedWindowCapture: NSObject, SCStreamOutput, SCStreamDelegate {
    private let picker = SCContentSharingPicker.shared
    private let session = CaptureSession()
    private let identity = ProcessIdentityProvider()
    private var stream: SCStream?
    private let lifetime = StreamLifetime()
    private var stopMessage = "Window access stopped. WhatsApp remains visible."
    private var pickerObserver: PickerRequestObserver?
    private var watchdog: Timer?
    private var original: NSRunningApplication?
    private var observers: [NSObjectProtocol] = []
    private var pendingPicker = false
    private var activeToken: UInt64 = 0
    public var onStatus: ((String, Bool) -> Void)?

    public var canChoose: Bool { lifetime.canBegin && stream == nil && !pendingPicker }

    public override init() {
        super.init()
        let center = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.sessionDidResignActiveNotification, NSWorkspace.screensDidSleepNotification] {
            observers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                self?.stop(message: "Paused — window access stopped. WhatsApp remains visible.", paused: true)
            })
        }
    }
    public func choose(settings: BlurSettings) {
        precondition(Thread.isMainThread)
        guard canChoose,
              let token = session.request(settings: settings, now: ProcessInfo.processInfo.systemUptime) else { return }
        activeToken = token; pendingPicker = true
        let observer = PickerRequestObserver(owner: self, token: token)
        pickerObserver = observer; picker.add(observer)
        var configuration = SCContentSharingPickerConfiguration()
        configuration.allowedPickerModes = [.singleWindow]
        configuration.allowsChangingSelectedContent = false
        picker.defaultConfiguration = configuration
        picker.maximumStreamCount = 1
        picker.isActive = true
        onStatus?("Choose one WhatsApp window. No blur is active.", true)
        picker.present(using: .window)
    }
    public func stop(message: String = "Window access stopped. WhatsApp remains visible.", paused: Bool = false) {
        precondition(Thread.isMainThread)
        session.stop(paused: paused); activeToken = session.token
        original = nil; pendingPicker = false; stopMessage = message
        picker.isActive = false
        if let observer = pickerObserver { picker.remove(observer); pickerObserver = nil }
        guard let old = stream else {
            watchdog?.invalidate(); watchdog = nil
            onStatus?(message, !lifetime.canBegin); return
        }
        // Keep the stream and the stopping status until both start and stop are acknowledged.
        let action = lifetime.requestStop(now: ProcessInfo.processInfo.systemUptime)
        onStatus?("Stopping window access… No blur is active.", true)
        perform(action, stream: old, token: lifetime.token)
    }
    private func perform(_ action: StreamAction, stream old: SCStream, token: UInt64) {
        switch action {
        case .none: break
        case .stop:
            old.stopCapture { [weak self] error in
                DispatchQueue.main.async {
                    guard let self = self, self.stream === old, self.lifetime.token == token else { return }
                    let next = self.lifetime.stopCompleted(token: token, succeeded: error == nil,
                                                          now: ProcessInfo.processInfo.systemUptime)
                    self.perform(next, stream: old, token: token)
                }
            }
        case .release:
            try? old.removeStreamOutput(self, type: .screen)
            stream = nil
            stop(message: stopMessage)
        case .terminate:
            onStatus?("Could not confirm capture stopped. Closing the preview.", true)
            NSApp.terminate(nil)
        }
    }
    fileprivate func pickerCancelled(token: UInt64, failed: Bool) {
        guard token == activeToken else { return }
        stop(message: failed ? "Window selection unavailable. No blur is active." : "Selection cancelled. No window access or blur is active.")
    }
    fileprivate func accept(_ filter: SCContentFilter, replacing: SCStream?, token: UInt64) {
        precondition(Thread.isMainThread)
        switch PickerEventPolicy.action(token: token, currentToken: activeToken, selecting: pendingPicker,
                                       hasStream: stream != nil, replacing: replacing != nil) {
        case .ignore: return
        case .stopUnexpected:
            stop(message: "Unexpected selection change rejected. No blur is active."); return
        case .acceptInitial: break
        }
        guard lifetime.canBegin else { stop(); return }
        pendingPicker = false
        guard PickerScope.isSingleWindow(windowStyle: filter.style == .window,
                  windowIDs: filter.includedWindows.map(\.windowID),
                  ownerPIDs: filter.includedWindows.map { $0.owningApplication?.processID ?? -1 },
                  displayCount: filter.includedDisplays.count,
                  applicationPIDs: filter.includedApplications.map(\.processID)),
              let selected = filter.includedWindows.first, selected.isOnScreen, let owner = selected.owningApplication,
              let app = NSRunningApplication(processIdentifier: owner.processID),
              app.bundleIdentifier == "net.whatsapp.WhatsApp", owner.bundleIdentifier == "net.whatsapp.WhatsApp",
              let generation = app.launchDate?.timeIntervalSince1970 else {
            stop(message: "Select a single native WhatsApp window. Other content is rejected."); return
        }
        identity.invalidate()
        let descriptor = SelectionDescriptor(windowID: selected.windowID, pid: owner.processID, generation: generation,
            bundleIdentifier: owner.bundleIdentifier, singleWindow: true,
            trusted: identity.trustedPIDs([app]).contains(owner.processID) && ProcessIdentityProvider.stillCurrent(app) && windowOwnedBy(selected.windowID, pid: owner.processID))
        guard session.accept(descriptor, token: activeToken, now: ProcessInfo.processInfo.systemUptime) else {
            stop(message: "WhatsApp publisher or window could not be authenticated. No frame accepted."); return
        }
        // Preserve the system-issued consent-bearing filter after checking its exact scope.
        let scope = filter
        let width = ceil(scope.contentRect.width * CGFloat(scope.pointPixelScale))
        let height = ceil(scope.contentRect.height * CGFloat(scope.pointPixelScale))
        guard let configuration = CaptureConfiguration.make(width: Double(width), height: Double(height)) else {
            stop(message: "Window exceeds the preview's supported size. No blur is active."); return
        }
        original = app
        let next = SCStream(filter: scope, configuration: configuration, delegate: self)
        do { try next.addStreamOutput(self, type: .screen, sampleHandlerQueue: .main) }
        catch { stop(message: "Could not create the window-only test stream. No blur is active."); return }
        guard let streamToken = lifetime.begin(now: ProcessInfo.processInfo.systemUptime) else {
            try? next.removeStreamOutput(self, type: .screen)
            stop(message: "Capture lifecycle unavailable. No blur is active."); return
        }
        stream = next
        onStatus?("Testing selected-window access… WhatsApp is visible and unprotected.", true)
        next.startCapture { [weak self] error in
            DispatchQueue.main.async {
                guard let self = self, self.stream === next, self.lifetime.token == streamToken else { return }
                if error != nil && !self.lifetime.isStopping {
                    self.stopMessage = "Window access failed or was denied. No blur is active."
                }
                let action = self.lifetime.startCompleted(token: streamToken, succeeded: error == nil,
                                                          now: ProcessInfo.processInfo.systemUptime)
                self.perform(action, stream: next, token: streamToken)
            }
        }
        let timer = Timer(timeInterval: 0.25, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            if self.lifetime.isStopping {
                if let current = self.stream {
                    self.perform(self.lifetime.poll(now: ProcessInfo.processInfo.systemUptime),
                                 stream: current, token: self.lifetime.token)
                }
                return
            }
            self.session.tick(now: ProcessInfo.processInfo.systemUptime)
            if !self.session.wantsFrames || self.original.map({ !ProcessIdentityProvider.stillCurrent($0) }) != false {
                self.stop(message: "Test ended without a valid current frame. No blur is active.")
            }
        }
        watchdog = timer; RunLoop.main.add(timer, forMode: .common)
    }
    public func stream(_ stream: SCStream, didStopWithError error: Error) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self, self.stream === stream else { return }
            self.stop(message: "Window access ended. No blur is active.")
        }
    }
    public func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        precondition(Thread.isMainThread)
        guard stream === self.stream, session.wantsFrames, type == .screen,
              CMSampleBufferIsValid(sampleBuffer),
              let attachments = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, createIfNecessary: false) as? [[SCStreamFrameInfo: Any]],
              let raw = attachments.first?[.status] as? Int, SCFrameStatus(rawValue: raw) == .complete,
              let pixels = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        identity.invalidate()
        let trusted = original.map { ProcessIdentityProvider.stillCurrent($0) && identity.trustedPIDs([$0]).contains($0.processIdentifier) && session.target.map({ windowOwnedBy($0.windowID, pid: $0.pid) }) == true } ?? false
        let now = ProcessInfo.processInfo.systemUptime
        let accepted = session.consumeFrame(token: activeToken, capturedAt: CMTimeGetSeconds(CMSampleBufferGetPresentationTimeStamp(sampleBuffer)),
            now: now, width: CVPixelBufferGetWidth(pixels), height: CVPixelBufferGetHeight(pixels), targetStillTrusted: trusted)
        // No pixel lock, image conversion, display, save, log, or reference stored.
        stop(message: accepted
            ? "Window access test passed; access stopped. Message detection is not implemented — no blur is active."
            : "Frame validation failed; access stopped. No blur is active.")
    }
    private func windowOwnedBy(_ windowID: UInt32, pid: Int32) -> Bool {
        // Query this selected window only; never consume titles or enumerate screen content.
        let records = CGWindowListCopyWindowInfo(.optionIncludingWindow, windowID) as? [[String: Any]] ?? []
        return WindowMetadataDecoder.decode(records, ownerPIDs: [pid]).contains { $0.id == windowID }
    }
    deinit {
        watchdog?.invalidate()
        for observer in observers { NSWorkspace.shared.notificationCenter.removeObserver(observer) }
    }
}

/// A new observer per picker request binds queued callbacks to their original session.
/// Removing an observer alone does not invalidate work already queued on the main thread.
private final class PickerRequestObserver: NSObject, SCContentSharingPickerObserver {
    weak var owner: SelectedWindowCapture?
    let token: UInt64
    init(owner: SelectedWindowCapture, token: UInt64) { self.owner = owner; self.token = token }
    func contentSharingPicker(_ picker: SCContentSharingPicker, didCancelFor stream: SCStream?) {
        let token = token
        DispatchQueue.main.async { [weak owner] in owner?.pickerCancelled(token: token, failed: false) }
    }
    func contentSharingPickerStartDidFailWithError(_ error: Error) {
        let token = token
        DispatchQueue.main.async { [weak owner] in owner?.pickerCancelled(token: token, failed: true) }
    }
    func contentSharingPicker(_ picker: SCContentSharingPicker, didUpdateWith filter: SCContentFilter, for stream: SCStream?) {
        let token = token
        DispatchQueue.main.async { [weak owner] in owner?.accept(filter, replacing: stream, token: token) }
    }
}

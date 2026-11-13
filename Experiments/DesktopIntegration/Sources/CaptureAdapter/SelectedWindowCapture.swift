import AppKit
import ScreenCaptureKit
import CoreMedia
import CoreVideo
import CoreImage
import IntegrationCore
import PrivacyCore

public enum CaptureStopReason { case explicit,geometry,transient,security,permission,session }
public struct CapturedWindowFrame {
    public let image: CGImage
    public var binding: FrameBinding
    public init(image: CGImage,binding: FrameBinding) { self.image = image; self.binding = binding }
}
/// Picker-scoped continuous frames for the explicitly authorized local test candidate.
/// No content is saved, logged, or sent outside the process.
public final class SelectedWindowCapture: NSObject, SCStreamOutput, SCStreamDelegate {
    public let trace = StartupTrace()
    public private(set) var stopReason:CaptureStopReason = .explicit
    private lazy var picker = SCContentSharingPicker.shared
    private let session = CaptureSession(continuous: true)
    private let imageContext = CIContext(options: [.cacheIntermediates: false])
    private var sequence: UInt64 = 0
    public var latestReceivedSequence:UInt64 { sequence }
    private let conversionQueue = DispatchQueue(label:"local.whatsapp.frame-copy",qos:.userInitiated)
    private var converting = false
    private var pendingConversion:(DecodedWindowSample,FrameBinding,NSRunningApplication)?
    private var lastSample = "no callback received"
    private var selectedSize: CGSize?
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
    public var onFrame: ((CapturedWindowFrame) -> Void)?
    public var onIdle: ((TimeInterval) -> Void)?
    public var onActivity: (() -> Void)?
    public var onStopped: (() -> Void)?
    public var isCapturing: Bool { session.wantsFrames }

    public var canChoose: Bool { lifetime.canBegin && stream == nil && !pendingPicker }

    public override init() {
        super.init()
        let center = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.sessionDidResignActiveNotification, NSWorkspace.screensDidSleepNotification] {
            observers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                self?.stop(message: "Paused — window access stopped. WhatsApp remains visible.", paused: true,reason:.session)
            })
        }
    }
    public func choose(settings: BlurSettings) {
        precondition(Thread.isMainThread)
        guard canChoose,
              let token = session.request(settings: settings, now: ProcessInfo.processInfo.systemUptime) else { return }
        activeToken = token; pendingPicker = true; lastSample = "no callback received"
        let observer = PickerRequestObserver(owner: self, token: token)
        pickerObserver = observer; picker.add(observer)
        var configuration = SCContentSharingPickerConfiguration()
        configuration.allowedPickerModes = [.singleWindow]
        configuration.allowsChangingSelectedContent = false
        picker.defaultConfiguration = configuration
        picker.maximumStreamCount = 1
        picker.isActive = true
        onStatus?("Choose one WhatsApp window for local experimental rendering.", true)
        trace.record(.selecting,now:ProcessInfo.processInfo.systemUptime)
        installWatchdog()
        picker.present(using: .window)
    }
    // Internal entry for authenticated automatic discovery. Uses the same scope, publisher,
    // generation, ownership, freshness and serialized stream-lifetime checks as selection.
    func startAutomatically(filter:SCContentFilter,settings:BlurSettings) {
        precondition(Thread.isMainThread)
        guard canChoose,ScreenPermission.preflight(),
              let token = session.request(settings:settings,now:ProcessInfo.processInfo.systemUptime) else { return }
        activeToken = token;pendingPicker = true
        accept(filter,replacing:nil,token:token)
    }
    public func stop(message: String = "Window access stopped. WhatsApp remains visible.", paused: Bool = false,reason:CaptureStopReason = .explicit) {
        stopReason = reason
        precondition(Thread.isMainThread)
        session.stop(paused: paused); activeToken = session.token
        original = nil; selectedSize = nil; pendingPicker = false; stopMessage = message;pendingConversion = nil
        onStopped?()
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
            stop(message: stopMessage,reason:stopReason)
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
            stop(message: "Select a single native WhatsApp window. Other content is rejected.",reason:.security); return
        }
        trace.record(.authenticating,now:ProcessInfo.processInfo.systemUptime)
        identity.invalidate()
        let descriptor = SelectionDescriptor(windowID: selected.windowID, pid: owner.processID, generation: generation,
            bundleIdentifier: owner.bundleIdentifier, singleWindow: true,
            trusted: identity.trustedPIDs([app]).contains(owner.processID) && ProcessIdentityProvider.stillCurrent(app) && windowOwnedBy(selected.windowID, pid: owner.processID))
        guard session.accept(descriptor, token: activeToken, now: ProcessInfo.processInfo.systemUptime) else {
            stop(message: "WhatsApp publisher or window could not be authenticated. No frame accepted.",reason:.security); return
        }
        // Preserve the system-issued consent-bearing filter after checking its exact scope.
        let scope = filter
        let width = ceil(scope.contentRect.width * CGFloat(scope.pointPixelScale))
        let height = ceil(scope.contentRect.height * CGFloat(scope.pointPixelScale))
        guard let configuration = CaptureConfiguration.make(width: Double(width), height: Double(height)) else {
            stop(message: "Window exceeds the supported size. No blur is active.",reason:.security); return
        }
        original = app; selectedSize = selected.frame.size; sequence = 0
        let next = SCStream(filter: scope, configuration: configuration, delegate: self)
        do { try next.addStreamOutput(self, type: .screen, sampleHandlerQueue: .main) }
        catch { stop(message: "Could not create the window-only test stream. No blur is active."); return }
        guard let streamToken = lifetime.begin(now: ProcessInfo.processInfo.systemUptime) else {
            try? next.removeStreamOutput(self, type: .screen)
            stop(message: "Capture lifecycle unavailable. No blur is active."); return
        }
        stream = next
        onStatus?("Analyzing the selected window locally… Coverage is unverified.", true)
        next.startCapture { [weak self] error in
            DispatchQueue.main.async {
                guard let self = self, self.stream === next, self.lifetime.token == streamToken else { return }
                if error != nil && !self.lifetime.isStopping {
                    self.stopMessage = "Window access failed or was denied. No blur is active.";self.stopReason = ScreenPermission.preflight() ? .transient : .permission
                }
                let action = self.lifetime.startCompleted(token: streamToken, succeeded: error == nil,
                                                          now: ProcessInfo.processInfo.systemUptime)
                self.perform(action, stream: next, token: streamToken)
            }
        }
        installWatchdog()
    }
    private func installWatchdog() {
        watchdog?.invalidate()
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
            if self.session.state == .selecting { return }
            if !self.session.wantsFrames {
                let detail = self.session.failure == .selectionTimeout ? "Selection did not complete within30 seconds. Try again."
                    : self.session.failure == .initialFrameTimeout ? "No usable initial image within 15 seconds (\(self.lastSample))."
                    : "Capture validation failed: \(self.session.failure?.rawValue ?? "inactive session")."
                self.stop(message: detail + " Access stopped; no blur is active.",reason:.transient)
            } else if self.original.map({ !ProcessIdentityProvider.stillCurrent($0) }) != false {
                self.stop(message: "Selected WhatsApp process changed. Access stopped; no blur is active.",reason:.security)
            }

        }
        watchdog = timer; RunLoop.main.add(timer, forMode: .common)
    }
    public func stream(_ stream: SCStream, didStopWithError error: Error) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self, self.stream === stream else { return }
            self.stop(message: "Window access ended. No blur is active.",reason:ScreenPermission.preflight() ? .transient : .permission)
        }
    }
    public func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        precondition(Thread.isMainThread)
        guard stream === self.stream,session.wantsFrames,type == .screen else { return }
        let decoded = FrameSampleDecoder.decode(sampleBuffer)
        let event = decoded.kind
        let raw = decoded.status ?? -1
        lastSample = decoded.status == nil ? "callback missing frame status" : "status \(raw), \(event.rawValue)"
        if event == .ignored { return }
        if event == .unavailable {
            stop(message: "Selected window updates suspended or unavailable (status \(raw)). Access stopped; no blur is active.",reason:.transient); return
        }
        let now = ProcessInfo.processInfo.systemUptime
        if event == .unchanged { identity.invalidate() }
        let trusted = original.map { ProcessIdentityProvider.stillCurrent($0) && (event != .unchanged || identity.trustedPIDs([$0]).contains($0.processIdentifier)) } ?? false
        guard let target = session.target, trusted, let rect = windowFrame(target.windowID,pid: target.pid) else {
            stop(message: "Selected WhatsApp identity/window changed. Rendering stopped.",reason:.security); return
        }
        if event == .unchanged {
            if !session.observeIdle(token: activeToken,now: now,targetStillTrusted: true) { stop(message: "Window stream expired. No blur is active.") }
            else if !converting && pendingConversion == nil { onIdle?(now) }
            return
        }
        trace.record(.frameReceived,now:now)
        sequence &+= 1
        onActivity?() // Revoke any sharp reveal before work is queued.
        guard decoded.pixels != nil, let selectedSize = selectedSize,
              abs(rect.width-selectedSize.width) < 1, abs(rect.height-selectedSize.height) < 1 else {
            stop(message: "Window size changed. Reconnecting; no blur is active.",reason:.geometry); return
        }
        let binding = FrameBinding(session:activeToken,sequence:sequence,windowID:target.windowID,processID:target.pid,
            processGeneration:target.generation,capturedAt:decoded.capturedAt ?? .nan,width:0,height:0,scale:0,windowFrame:rect)
        guard let process = original else { return }
        pendingConversion = (decoded,binding,process);convertNewest()
    }
    private func convertNewest() {
        guard !converting,let work = pendingConversion else { return }
        pendingConversion = nil;converting = true
        conversionQueue.async { [weak self] in
            guard let self = self else { return }
            let result:(CGImage?,Bool) = autoreleasepool {
                let validator = ProcessIdentityProvider()
                let trusted = ProcessIdentityProvider.stillCurrent(work.2) && validator.trustedPIDs([work.2]).contains(work.1.processID)
                return (trusted ? work.0.normalizedImage(context:self.imageContext,windowSize:work.1.windowFrame.size) : nil,trusted)
            }
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return };self.converting = false
                defer { self.convertNewest() }
                guard self.session.wantsFrames,work.1.session == self.activeToken else { return }
                guard result.1 else { self.stop(message:"WhatsApp publisher changed. No blur is active.",reason:.security);return }
                guard let image = result.0 else { self.stop(message:"Frame transform could not be verified. No blur is active.",reason:.geometry);return }
                let now = ProcessInfo.processInfo.systemUptime
                var binding = work.1;binding.width = image.width;binding.height = image.height
                binding.scale = Double(image.width)/Double(binding.windowFrame.width)
                guard self.session.consumeFrame(token:binding.session,capturedAt:binding.capturedAt,now:now,width:image.width,height:image.height,targetStillTrusted:true),
                      self.validatedWindowFrame(for:binding) == binding.windowFrame else {
                    self.stop(message:"Frame is delayed or the window changed. Reconnecting.",reason:.transient);return
                }
                self.onFrame?(CapturedWindowFrame(image:image,binding:binding))
            }
        }
    }
    /// Revalidate the entire consent/identity binding immediately before external presentation.
    public func validatedWindowFrame(for binding: FrameBinding) -> CGRect? {
        guard session.wantsFrames,binding.session == activeToken else { return nil }
        guard TargetBinding.isCurrent(binding,selection: session.target,token: activeToken,
                  currentGeneration: original?.launchDate?.timeIntervalSince1970,
                  processStillCurrent: original.map(ProcessIdentityProvider.stillCurrent) ?? false) else {
            stop(message:"WhatsApp process identity changed. No blur is active.",reason:.security);return nil
        }
        guard let rect = windowFrame(binding.windowID,pid: binding.processID),rect == binding.windowFrame else {
            stop(message: "Window identity or bounds changed. Reconnecting; no blur is active.",reason:.geometry); return nil
        }
        return rect
    }
    private func windowFrame(_ windowID: UInt32,pid: Int32) -> CGRect? {
        let records = CGWindowListCopyWindowInfo(.optionIncludingWindow,windowID) as? [[String: Any]] ?? []
        return WindowMetadataDecoder.decode(records,ownerPIDs: [pid]).first(where: { $0.id == windowID })?.frame
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

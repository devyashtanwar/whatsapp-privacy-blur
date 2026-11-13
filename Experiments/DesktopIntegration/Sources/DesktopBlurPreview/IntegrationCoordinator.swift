import AppKit
import CoreGraphics
import CaptureAdapter
import IntegrationCore
import DesktopPipeline
import NativeRendering

/// Experimental native integration. No supported/protected status is emitted here.
final class IntegrationCoordinator {
    let capture = SelectedWindowCapture()
    var onCaptureStopped:((CaptureStopReason)->Void)?
    var onStatus: ((String) -> Void)?
    private(set) var settings = BlurSettings()
    private let worker = DispatchQueue(label: "local.whatsapp.region-render",qos: .userInitiated)
    private let gate = FramePipeline()
    private var hover = ExternalHover()
    private var timer: Timer?
    private var latest: CapturedWindowFrame?
    private var pending: CapturedWindowFrame?
    private var displayed: CapturedWindowFrame?
    private var displayedPlan: RegionPlan?
    private var conversationAvailable = false
    private var blurred: CGImage?
    private var busy = false
    private var activity: UInt64 = 0
    private var renderedReveal: UInt64?
    private var wasFrontmost = false
    private let presentation = TargetPresentation()

    init(settings:BlurSettings = BlurSettings()) {
        self.settings = settings
        capture.onStopped = { [weak self] in guard let self = self else { return };self.clear();self.onCaptureStopped?(self.capture.stopReason) }
        capture.onActivity = { [weak self] in
            guard let self = self else { return }
            self.activity &+= 1
            self.hover.newFrame(sequence: self.activity,now: ProcessInfo.processInfo.systemUptime)
            self.restoreBlur()
        }
        capture.onFrame = { [weak self] frame in
            guard let self = self else { return }
            self.latest = frame
            self.pending = frame; self.pump()
        }
        capture.onIdle = { [weak self] now in
            guard let self = self, var latest = self.latest else { return }
            // SCK idle attests no new content since the latest complete frame.
            latest.binding.capturedAt = now; self.latest = latest
        }
        let clock = Timer(timeInterval: 0.05,repeats: true) { [weak self] _ in self?.tick() }
        timer = clock; RunLoop.main.add(clock,forMode: .common)
    }
    func update(_ settings: BlurSettings) {
        self.settings = settings; gate.reset(); hover = ExternalHover()
        activity &+= 1; hover.newFrame(sequence: activity,now: ProcessInfo.processInfo.systemUptime)
        withdraw(); displayed = nil; displayedPlan = nil; blurred = nil; renderedReveal = nil
        pending = latest
        if !settings.needsCapture { capture.stop(message: "All blur categories are off. Window access stopped.") }
        else { pump() }
    }
    func choose(_ settings: BlurSettings) { self.settings = settings; clear(); capture.choose(settings: settings) }
    func stop() { capture.stop() }
    private func clear() {
        gate.reset(); hover = ExternalHover(); latest = nil; pending = nil; displayed = nil
        displayedPlan = nil; blurred = nil; renderedReveal = nil; wasFrontmost = false
        withdraw()
        // A synchronous Vision/filter request already executing may finish; its result is discarded.
    }
    private func pump() {
        guard !busy,settings.needsCapture,capture.isCapturing,let input = pending else { return }
        pending = nil
        busy = true
        capture.trace.record(.analyzing,now:ProcessInfo.processInfo.systemUptime)
        let revision = gate.revision, options = settings
        worker.async { [weak self] in
            let result = autoreleasepool { FrameProcessor.process(input,settings:options) }
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.busy = false
                defer { self.pump() }
                guard revision == self.gate.revision,self.capture.isCapturing else { return }
                var bound = input
                if let current = self.latest,current.binding.sequence == input.binding.sequence,current.binding.session == input.binding.session {
                    bound.binding.capturedAt = current.binding.capturedAt
                }
                let now = ProcessInfo.processInfo.systemUptime
                guard let result = result else {
                    self.discardPublication()
                    self.onStatus?("Selected blur categories could not be located. No rendering is active; keep a supported chat list visible.")
                    return
                }
                var current = result; current.source = bound
                let delivery = self.gate.deliver(current,revision:revision,
                    currentWindow:self.capture.validatedWindowFrame(for:bound.binding),now:now) { processed in
                    self.capture.trace.record(.prepared,now:ProcessInfo.processInfo.systemUptime)
                    self.cachePrepared(current)
                    return self.present(processed.image,for:bound.binding)
                }
                switch delivery {
                case .rejected: self.discardPublication(); self.onStatus?("Frame delayed or window changed. No current rendering; coverage is unverified.")
                case .displayed: self.reportRendering()
                case .prepared: self.onStatus?("Image prepared; native window ordering is unconfirmed. No current overlay.")
                }

            }
        }
    }
    private func tick() {
        guard capture.isCapturing,let latest = latest else { withdraw(); return }
        let foreground = NSWorkspace.shared.frontmostApplication?.processIdentifier == latest.binding.processID
        if !foreground { hover.visibilityChanged(false,now:ProcessInfo.processInfo.systemUptime); if renderedReveal != nil { restoreBlur() };wasFrontmost = false }
        if foreground && !wasFrontmost {
            wasFrontmost = true; hover = ExternalHover(); activity &+= 1
            hover.newFrame(sequence: activity,now: ProcessInfo.processInfo.systemUptime)
            if displayed?.binding.sequence != latest.binding.sequence { pending = latest; pump() }
        }
        guard let current = displayed, let plan = displayedPlan else { withdraw(); return }
        guard DisplayFreshness.allows(current.binding,latestReceivedSequence:capture.latestReceivedSequence,now:ProcessInfo.processInfo.systemUptime) else {
            discardPublication();onStatus?("Processed image expired while content changed. No current rendering; WhatsApp is visible.");return
        }
        guard visible(current.binding) else { visibilityLost(); return }
        hover.visibilityChanged(true,now: ProcessInfo.processInfo.systemUptime)
        if presentation.isVisible {
            guard presentation.maintainOrder(target:current.binding.windowID) else { visibilityLost();return }
        } else if let blurred = blurred,present(blurred,for:current.binding) { reportRendering() }
        guard foreground else { return }
        let now = ProcessInfo.processInfo.systemUptime
        guard latest.binding.sequence == current.binding.sequence,now-latest.binding.capturedAt <= 1 else {
            hover.invalidate(); restoreBlur()
            onStatus?("Waiting for a new window image. Last processed image shown; hover paused. Coverage unverified."); return
        }
        let point = NSEvent.mouseLocation
        guard let primary = NSScreen.screens.first else { return }
        let quartz = CGPoint(x: point.x,y: primary.frame.maxY-point.y)
        let r = current.binding.windowFrame
        guard presentation.hoverRegions(binding:current.binding).contains(where:{$0.contains(quartz)}) else {
            hover.visibilityChanged(false,now:now);restoreBlur();return
        }
        let pixel = CGPoint(x: (quartz.x-r.minX)*CGFloat(current.binding.width)/r.width,
                            y: (r.maxY-quartz.y)*CGFloat(current.binding.height)/r.height)
        // Identity wins overlapping hit tests and can never be revealed.
        let identity = plan.regions.first { ($0.category == .contactName || $0.category == .avatar) && settings.isEnabled($0.category) && $0.bounds.contains(pixel) }
        let region = identity ?? plan.regions.first { settings.permitsHover($0.category) && $0.bounds.contains(pixel) }
        let reveal = hover.pointer(pixel,region: region,settings: settings,now: now)
        guard reveal != renderedReveal else { return }
        restoreBlur()
        if reveal == nil || busy { return }
        busy = true
        // Rendering a reveal stays off the event loop. The same revision/frame/reveal must still hold.
        let revision = gate.revision, options = settings, activity = self.activity, hoverRevision = hover.revision
        worker.async { [weak self] in
            let image = autoreleasepool { FrameCompositor.render(current.image,plan: plan,settings: options,reveal: reveal) }
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.busy = false
                defer { self.pump() }
                guard revision == self.gate.revision,activity == self.activity,
                      self.displayed?.binding.sequence == current.binding.sequence,self.hover.permitsCompletion(revision: hoverRevision,item: reveal,now: ProcessInfo.processInfo.systemUptime),
                      let image = image,self.visible(current.binding) else { return }
                self.renderedReveal = reveal
                self.present(image,for: current.binding)
            }
        }
    }
    var hasPreparedImage:Bool { displayed != nil && displayedPlan != nil && blurred != nil }
    func cachePrepared(_ processed:ProcessedWindowFrame) {
        displayed = processed.source;displayedPlan = processed.plan;blurred = processed.image;renderedReveal = nil
        conversationAvailable = processed.conversationAvailable
    }
    func discardPublication() {
        hover.invalidate();displayed = nil;displayedPlan = nil;blurred = nil;renderedReveal = nil;withdraw()
    }
    private func restoreBlur() {
        renderedReveal = nil
        if let image = blurred,let binding = displayed?.binding,visible(binding) { present(image,for: binding) }
        else { visibilityLost() }
    }
    private func visibilityLost() {
        hover.visibilityChanged(false,now: ProcessInfo.processInfo.systemUptime)
        activity &+= 1; renderedReveal = nil; withdraw()
    }
    private func visible(_ binding:FrameBinding) -> Bool {
        capture.validatedWindowFrame(for:binding) == binding.windowFrame
    }
    private func reportRendering() {
        let missing = settings.conversationMessages && !conversationAvailable ? " Conversation detection unavailable in this view." : ""
        onStatus?("Experimental rendering. Coverage unverified." + missing)
    }
    @discardableResult private func present(_ image:CGImage,for binding:FrameBinding) -> Bool {
        guard DisplayFreshness.allows(binding,latestReceivedSequence:capture.latestReceivedSequence,now:ProcessInfo.processInfo.systemUptime) else { discardPublication();return false }
        guard visible(binding),let primary = NSScreen.screens.first else { visibilityLost();return false }
        guard presentation.install(image,binding:binding,primaryMaxY:primary.frame.maxY) else { return false }
        capture.trace.record(.displayed,now:ProcessInfo.processInfo.systemUptime);return true
    }
    private func withdraw() { presentation.withdraw() }
    deinit { timer?.invalidate() }
}

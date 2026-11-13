import AppKit
import CoreGraphics
import CaptureAdapter
import IntegrationCore
import GeometryAnalysis
import NativeRendering

/// Experimental native integration. No supported/protected status is emitted here.
final class IntegrationCoordinator {
    let capture = SelectedWindowCapture()
    var onStatus: ((String) -> Void)?
    private var settings = BlurSettings()
    private let worker = DispatchQueue(label: "local.whatsapp.region-render",qos: .userInitiated)
    private let gate = PublicationGate()
    private var hover = ExternalHover()
    private var timer: Timer?
    private var latest: CapturedWindowFrame?
    private var pending: CapturedWindowFrame?
    private var displayed: CapturedWindowFrame?
    private var displayedPlan: RegionPlan?
    private var blurred: CGImage?
    private var busy = false
    private var activity: UInt64 = 0
    private var renderedReveal: UInt64?
    private var wasFrontmost = false
    private var overlay: NSWindow?
    private var imageView: NSImageView?

    init() {
        capture.onStopped = { [weak self] in self?.clear() }
        capture.onActivity = { [weak self] in
            guard let self = self else { return }
            self.activity &+= 1
            self.hover.newFrame(sequence: self.activity,now: ProcessInfo.processInfo.systemUptime)
            self.restoreBlur()
        }
        capture.onFrame = { [weak self] frame in
            guard let self = self else { return }
            self.latest = frame
            guard NSWorkspace.shared.frontmostApplication?.processIdentifier == frame.binding.processID else { return }
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
        guard NSWorkspace.shared.frontmostApplication?.processIdentifier == input.binding.processID else { return }
        busy = true
        let revision = gate.revision, options = settings
        worker.async { [weak self] in
            let result: (CGImage,RegionPlan)? = autoreleasepool {
                guard let detection = try? NativeLayoutDetector.detect(input.image) else { return nil }
                let plan = RegionPlan(.experimental,regions: detection.regions)
                guard let rendered = FrameCompositor.render(input.image,plan: plan,settings: options) else { return nil }
                return (rendered,plan)
            }
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
                    self.withdraw(); self.displayed = nil; self.displayedPlan = nil; self.blurred = nil
                    self.onStatus?("Layout not recognized. No blur is active. Open a normal chat with Search and an empty message field visible.")
                    return
                }
                guard self.gate.accept(revision: revision,frame: bound.binding,
                    currentWindow: self.capture.validatedWindowFrame(for: bound.binding),
                    frontmost: NSWorkspace.shared.frontmostApplication?.processIdentifier == bound.binding.processID,now: now) else {
                    self.withdraw(); self.onStatus?("Frame delayed or window changed. No current rendering; coverage is unverified."); return
                }
                self.displayed = bound; self.displayedPlan = result.1; self.blurred = result.0; self.renderedReveal = nil
                self.present(result.0,for: bound.binding)
                self.onStatus?("Experimental rendering · \(result.1.regions.count) detected regions. Coverage is unverified; use a harmless test chat.")
            }
        }
    }
    private func tick() {
        guard capture.isCapturing,let latest = latest else { withdraw(); return }
        let foreground = NSWorkspace.shared.frontmostApplication?.processIdentifier == latest.binding.processID
        if !foreground { visibilityLost(); wasFrontmost = false; return }
        if !wasFrontmost {
            wasFrontmost = true; hover = ExternalHover(); activity &+= 1
            hover.newFrame(sequence: activity,now: ProcessInfo.processInfo.systemUptime); pending = latest; pump()
        }
        guard let current = displayed, let plan = displayedPlan else { withdraw(); return }
        guard visible(current.binding) else { visibilityLost(); return }
        hover.visibilityChanged(true,now: ProcessInfo.processInfo.systemUptime)
        if overlay?.isVisible != true, let blurred = blurred { present(blurred,for: current.binding) }
        let now = ProcessInfo.processInfo.systemUptime
        guard latest.binding.sequence == current.binding.sequence,now-latest.binding.capturedAt <= 1 else {
            hover.invalidate(); restoreBlur(); return
        }
        let point = NSEvent.mouseLocation
        guard let primary = NSScreen.screens.first else { return }
        let quartz = CGPoint(x: point.x,y: primary.frame.maxY-point.y)
        let r = current.binding.windowFrame
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
    private func restoreBlur() {
        renderedReveal = nil
        if let image = blurred,let binding = displayed?.binding,visible(binding) { present(image,for: binding) }
        else { visibilityLost() }
    }
    private func visibilityLost() {
        hover.visibilityChanged(false,now: ProcessInfo.processInfo.systemUptime)
        activity &+= 1; renderedReveal = nil; withdraw()
    }
    private func visible(_ binding: FrameBinding) -> Bool {
        guard NSWorkspace.shared.frontmostApplication?.processIdentifier == binding.processID,
              capture.validatedWindowFrame(for: binding) == binding.windowFrame else { return false }
        // Metadata only, never titles/pixels: don't draw through windows above the selected target.
        guard let records = CGWindowListCopyWindowInfo([.optionOnScreenAboveWindow,.excludeDesktopElements],binding.windowID) as? [[String: Any]] else { return false }
        for record in records {
            if (record[kCGWindowNumber as String] as? NSNumber)?.intValue == overlay?.windowNumber { continue }
            guard let alpha = record[kCGWindowAlpha as String] as? NSNumber,alpha.doubleValue > 0,
                  let bounds = record[kCGWindowBounds as String] as? [String: Any],let rect = CGRect(dictionaryRepresentation: bounds as CFDictionary) else { continue }
            if rect.intersects(binding.windowFrame.insetBy(dx: 2,dy: 2)) { return false }
        }
        return true
    }
    private func present(_ image: CGImage,for binding: FrameBinding) {
        guard visible(binding),let primary = NSScreen.screens.first else { visibilityLost(); return }
        if overlay == nil {
            let window = NSWindow(contentRect: .zero,styleMask: .borderless,backing: .buffered,defer: false)
            window.isReleasedWhenClosed = false; window.ignoresMouseEvents = true
            window.level = NSWindow.Level(rawValue: NSWindow.Level.normal.rawValue+1)
            window.backgroundColor = .clear; window.isOpaque = false; window.hasShadow = false
            window.collectionBehavior = [.transient,.ignoresCycle]
            let view = NSImageView(); view.imageScaling = .scaleAxesIndependently
            view.wantsLayer = true; view.layer?.cornerRadius = 10; view.layer?.masksToBounds = true
            window.contentView = view; overlay = window; imageView = view
        }
        let rect = binding.windowFrame
        let frame = CGRect(x: rect.minX,y: primary.frame.maxY-rect.maxY,width: rect.width,height: rect.height)
        imageView?.image = NSImage(cgImage: image,size: frame.size)
        overlay?.setFrame(frame,display: false); overlay?.orderFrontRegardless()
    }
    private func withdraw() { overlay?.orderOut(nil); imageView?.image = nil }
    deinit { timer?.invalidate() }
}

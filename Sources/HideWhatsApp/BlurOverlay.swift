import AppKit
import CoreImage

final class BlurOverlayWindow: NSWindow {
    private let imageView: NSImageView
    private let context = CIContext()
    private var mouseMonitor: Any?
    private var updateTimer: Timer?

    private(set) var isHovering = false

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    init() {
        imageView = NSImageView()
        imageView.imageScaling = .scaleAxesIndependently
        imageView.wantsLayer = true

        super.init(
            contentRect: .zero,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )

        level = .floating
        isOpaque = true
        backgroundColor = .windowBackgroundColor
        ignoresMouseEvents = false
        collectionBehavior = [.canJoinAllSpaces, .stationary]
        hasShadow = false

        contentView = imageView
        setupMouseMonitor()
    }

    private func setupMouseMonitor() {
        mouseMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.mouseMoved, .leftMouseDragged]
        ) { [weak self] _ in
            self?.handleMouseMoved()
        }
    }

    private func handleMouseMoved() {
        guard isVisible else { return }

        let mouseLocation = NSEvent.mouseLocation
        let isInside = frame.contains(mouseLocation)

        if isInside && !isHovering {
            mouseEntered()
        } else if !isInside && isHovering {
            mouseExited()
        }
    }

    private func mouseEntered() {
        isHovering = true
        ignoresMouseEvents = true

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            self.animator().alphaValue = 0.0
        }
    }

    private func mouseExited() {
        isHovering = false
        ignoresMouseEvents = false

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            self.animator().alphaValue = 1.0
        }
    }

    func updateFrame(_ newFrame: NSRect) {
        setFrame(newFrame, display: false)
        captureAndBlur()
    }

    func updateBlurIntensity() {
        captureAndBlur()
    }

    private func captureAndBlur() {
        guard frame.width > 0, frame.height > 0 else { return }

        // Convert from AppKit coordinates (bottom-left) to CGWindow coordinates (top-left)
        guard let screen = NSScreen.main else { return }
        let screenHeight = screen.frame.height
        let captureRect = CGRect(
            x: frame.origin.x,
            y: screenHeight - frame.origin.y - frame.height,
            width: frame.width,
            height: frame.height
        )

        // Capture screen content excluding our own window
        guard let cgImage = CGWindowListCreateImage(
            captureRect,
            .optionOnScreenBelowWindow,
            CGWindowID(windowNumber),
            [.bestResolution]
        ) else { return }

        // Apply blur
        let ciImage = CIImage(cgImage: cgImage)
        let blurRadius = blurRadiusForIntensity()

        guard let blurFilter = CIFilter(name: "CIGaussianBlur") else { return }
        blurFilter.setValue(ciImage, forKey: kCIInputImageKey)
        blurFilter.setValue(blurRadius, forKey: kCIInputRadiusKey)

        guard let outputImage = blurFilter.outputImage else { return }

        // Crop to original bounds (blur expands the image)
        let croppedImage = outputImage.cropped(to: ciImage.extent)

        // Render to CGImage
        guard let blurredCGImage = context.createCGImage(croppedImage, from: ciImage.extent) else { return }

        // Display
        let nsImage = NSImage(cgImage: blurredCGImage, size: frame.size)
        imageView.image = nsImage
    }

    private func blurRadiusForIntensity() -> CGFloat {
        switch Settings.shared.blurIntensity {
        case "light": return 15.0
        case "heavy": return 50.0
        default: return 30.0
        }
    }

    func show() {
        if !isHovering {
            alphaValue = 1.0
        }
        orderFront(nil)
        startUpdateTimer()
    }

    func hide() {
        orderOut(nil)
        stopUpdateTimer()
        if isHovering {
            isHovering = false
            ignoresMouseEvents = false
        }
    }

    private func startUpdateTimer() {
        stopUpdateTimer()
        updateTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self, self.isVisible, !self.isHovering else { return }
            self.captureAndBlur()
        }
    }

    private func stopUpdateTimer() {
        updateTimer?.invalidate()
        updateTimer = nil
    }

    deinit {
        stopUpdateTimer()
        if let monitor = mouseMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }
}

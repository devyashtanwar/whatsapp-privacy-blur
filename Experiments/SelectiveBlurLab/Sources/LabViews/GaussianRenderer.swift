import AppKit
import CoreImage

/// Draws invented text locally, not a screenshot or image from another app.
public final class GaussianMessageView: NSView {
    private let text: String
    private let fontSize: CGFloat
    private let bubble: NSColor
    private var cached: NSImage?
    private var cachedSize = NSSize.zero
    public private(set) var renderFailed = false
    public var tintOpacity = 0.65 {
        didSet { if oldValue != tintOpacity { cached = nil; needsDisplay = true } }
    }
    public init(text: String, fontSize: CGFloat, bubble: NSColor, frame: NSRect) {
        self.text = text; self.fontSize = fontSize; self.bubble = bubble
        super.init(frame: frame)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) unavailable") }
    public override var isOpaque: Bool { true }
    public override func hitTest(_ point: NSPoint) -> NSView? { nil }
    public override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance(); cached = nil; needsDisplay = true
    }
    public override func draw(_ dirtyRect: NSRect) {
        let base = NSColor.textBackgroundColor.withAlphaComponent(1)
        base.setFill(); bounds.fill() // Safe opaque fallback, even if filtering fails.
        if cachedSize != bounds.size { cached = nil; cachedSize = bounds.size }
        if cached == nil { cached = makeImage(base: base); renderFailed = cached == nil }
        let shape = NSBezierPath(roundedRect: bounds, xRadius: 7, yRadius: 7)
        NSGraphicsContext.saveGraphicsState(); shape.addClip()
        if let cached = cached { cached.draw(in: bounds) }
        else {
            ("Blur unavailable" as NSString).draw(in: bounds.insetBy(dx: 5, dy: 5), withAttributes: [.foregroundColor: NSColor.secondaryLabelColor, .font: NSFont.systemFont(ofSize: 11)])
        }
        NSGraphicsContext.restoreGraphicsState()
        NSColor.separatorColor.withAlphaComponent(0.16).setStroke(); shape.lineWidth = 0.5; shape.stroke()
    }
    private func makeImage(base: NSColor) -> NSImage? {
        guard bounds.width > 0, bounds.height > 0, bounds.width <= 2048, bounds.height <= 1024 else { return nil }
        let size = bounds.size
        let generated = NSImage(size: size, flipped: true) { rect in
            base.setFill(); rect.fill(); self.bubble.setFill(); rect.fill()
            let paragraph = NSMutableParagraphStyle(); paragraph.lineBreakMode = .byWordWrapping
            (self.text as NSString).draw(in: rect.insetBy(dx: 3, dy: 2), withAttributes: [
                .font: NSFont.systemFont(ofSize: self.fontSize), .foregroundColor: NSColor.labelColor, .paragraphStyle: paragraph])
            return true
        }
        guard let image = generated.cgImage(forProposedRect: nil, context: nil, hints: nil),
              let rgb = base.usingColorSpace(.deviceRGB) else { return nil }
        let tint = CIColor(red: rgb.redComponent, green: rgb.greenComponent, blue: rgb.blueComponent, alpha: 1)
        guard let blurred = GaussianRenderer.render(image, radius: max(8, Double(fontSize) * 0.6), tint: tint, tintOpacity: tintOpacity) else { return nil }
        return NSImage(cgImage: blurred, size: size)
    }
}

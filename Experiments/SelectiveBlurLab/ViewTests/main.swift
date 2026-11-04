import AppKit
import CoreImage
import Darwin
import LabViews
import LabPolicy

// Hidden view-tree tests only. No windows created, shown, captured or controlled.
var assertions = 0
var failures = 0
func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
    assertions += 1
    if !condition() { failures += 1; print("FAIL: \(message)") }
}
let clip = ScrollAwareClipView(frame: CGRect(x: 0, y: 0, width: 500, height: 200))
let document = NSView(frame: CGRect(x: 0, y: 0, width: 500, height: 1600))
clip.documentView = document
let surfaces = (1...3).map { id in
    MessageBlurSurface(id: id, content: NSView(), frame: CGRect(x: 30, y: id * 180, width: 300, height: 100))
}
for surface in surfaces { document.addSubview(surface) }
let controller = BlurPresentation()
controller.replace(surfaces); controller.setFocus(true); controller.setHoverEnabled(true)
expect(surfaces.allSatisfy(\.isBlurred), "all items protected before first display")
controller.pointerMoved(item: 1, position: CGPoint(x: 10, y: 10), now: 1)
expect(!surfaces[0].isBlurred && surfaces[1].isBlurred && surfaces[2].isBlurred, "hover reveals exactly one surface")
let identities = surfaces.map(ObjectIdentifier.init)
let effectIdentities = surfaces.map { ObjectIdentifier($0.effect) }
controller.tick(now: 1.01)
expect(surfaces[1].isBlurred && surfaces[2].isBlurred, "unrelated items remain blurred across presentation update")
var eventTime = 1.02
clip.onWillChange = { controller.scroll(.move, in: 0, now: eventTime) }
clip.scroll(to: CGPoint(x: 0, y: 181))
expect(surfaces.allSatisfy(\.isBlurred), "bounds change revokes reveal without a polling tick")
controller.tick(now: 1.3)
controller.pointerMoved(item: 2, position: CGPoint(x: 10, y: 10), now: 1.31)
expect(surfaces.allSatisfy(\.isBlurred), "stationary pointer cannot reveal another scrolled item")
controller.pointerMoved(item: 2, position: CGPoint(x: 11, y: 10), now: 1.32)
expect(!surfaces[1].isBlurred, "direct physical entry recovers without a blank sample")
controller.scroll(.move, in: 0, now: 1.4)
controller.scroll(.move, in: 1, now: 1.5)
controller.scroll(.end, in: 0, now: 1.51)
controller.pointerMoved(item: 3, position: CGPoint(x: 12, y: 10), now: 1.55)
expect(surfaces.allSatisfy(\.isBlurred), "a still-moving second pane blocks reveal")
controller.tick(now: 1.7)
expect(surfaces.allSatisfy(\.isBlurred), "quiet recovery never auto-reveals")
controller.pointerMoved(item: 3, position: CGPoint(x: 13, y: 10), now: 1.71)
expect(!surfaces[2].isBlurred, "missing end does not require a focus cycle")
controller.setFocus(false)
expect(surfaces.allSatisfy(\.isBlurred), "visible inactive content stays blurred")
controller.setFocus(true)
controller.pointerMoved(item: 3, position: CGPoint(x: 13, y: 10), now: 1.8)
expect(surfaces.allSatisfy(\.isBlurred), "focus regain does not renew stationary reveal")
controller.pointerMoved(item: 3, position: CGPoint(x: 14, y: 10), now: 1.81)
expect(!surfaces[2].isBlurred, "fresh deliberate movement after focus regain works")
controller.layoutWillChange()
eventTime = 2
// No timer is invoked throughout this rapid fractional/reversing scroll burst.
for y in [0.0, 0.5, 71.25, 400.0, 105.75, 999.0, 10.0] {
    eventTime += 0.01
    clip.scroll(to: CGPoint(x: 0, y: y))
    for surface in surfaces {
        expect(surface.convert(surface.bounds, to: clip) == surface.effect.convert(surface.effect.bounds, to: clip), "content/blur share fractional scroll transform")
        expect(surface.gaussian.convert(surface.gaussian.bounds, to: clip) == surface.convert(surface.bounds, to: clip), "Gaussian shares content scroll transform")
        expect(surface.effect.superview === surface, "blur remains inside content container")
        expect(surface.isBlurred, "offscreen and reentering regions already blurred")
    }
}
expect(surfaces.map(ObjectIdentifier.init) == identities, "scroll retains content surfaces")
expect(surfaces.map { ObjectIdentifier($0.effect) } == effectIdentities, "scroll retains blur views")
expect(surfaces.allSatisfy { $0.effect.hitTest(.zero) == nil }, "blur is click-through")
// Test real shared ancestor clipping at a partially visible message boundary.
clip.scroll(to: CGPoint(x: 0, y: 205.5))
let first = surfaces[0]
let visibleBody = first.convert(first.bounds, to: clip).intersection(clip.bounds)
let visibleBlur = first.effect.convert(first.effect.bounds, to: clip).intersection(clip.bounds)
expect(visibleBody == visibleBlur && visibleBody.height > 0 && visibleBody.height < 100, "partially visible blur clips with content")
first.frame.size = CGSize(width: 320, height: 110)
first.layoutSubtreeIfNeeded()
expect(first.effect.frame == first.bounds, "resizing content resizes its blur in the same tree: effect \(first.effect.frame), content \(first.bounds)")
for size in [NSSize(width: 320.25, height: 110.5), NSSize(width: 301.75, height: 91.125), NSSize(width: 450.125, height: 80.75)] {
    first.setFrameSize(size)
    first.layoutSubtreeIfNeeded()
    expect(first.gaussian.frame == first.bounds, "Gaussian shares exact fractional bounds")
    expect(first.effect.frame == first.bounds, "fractional resize retains exact coverage: effect \(first.effect.frame), content \(first.bounds)")
}
controller.setHoverEnabled(false)
expect(surfaces.allSatisfy(\.isBlurred), "hover off restores all masks")
// Exercise actual NSEvent classification used by PointerWindow, without a window.
for type in [NSEvent.EventType.mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged] {
    let event = NSEvent.mouseEvent(with: type, location: NSPoint(x: 12, y: 34), modifierFlags: [], timestamp: 1,
                                  windowNumber: 0, context: nil, eventNumber: 1, clickCount: 0, pressure: 0)!
    expect(FixturePointerEvents.location(for: event) == NSPoint(x: 12, y: 34), "all local pointer drags must update hover")
}
let click = NSEvent.mouseEvent(with: .leftMouseDown, location: .zero, modifierFlags: [], timestamp: 1,
                              windowNumber: 0, context: nil, eventNumber: 1, clickCount: 1, pressure: 0)!
expect(FixturePointerEvents.location(for: click) == nil, "click does not grant a fresh hover")
// Exercise the actual phase mapper and the report's incomplete stream.
expect(FixtureScrollEvents.signal(phase: .mayBegin, momentum: []) == .prepare, "tentative input is not movement")
expect(FixtureScrollEvents.signal(phase: .stationary, momentum: []) == nil, "stationary bookkeeping does not renew a lock")
expect(FixtureScrollEvents.signal(phase: [], momentum: .changed) == .move, "momentum maps to motion")
expect(FixtureScrollEvents.signal(phase: .ended, momentum: .changed) == .move, "momentum takes precedence over gesture end")
expect(FixtureScrollEvents.signal(phase: .cancelled, momentum: []) == .end, "cancel is a terminal observation")
expect(FixtureScrollEvents.signal(phase: [], momentum: []) == .move, "legacy wheel needs no event pairing")
let recovery = BlurPresentation()
recovery.replace(surfaces); recovery.setFocus(true); recovery.setHoverEnabled(true)
recovery.pointerMoved(item: 1, position: .zero, now: 30)
recovery.scroll(.move, in: 0, now: 30.01); recovery.scroll(.prepare, in: 0, now: 30.02)
recovery.scroll(.end, in: 0, now: 30.03); recovery.scroll(.move, in: 1, now: 30.04)
recovery.tick(now: 31)
expect(surfaces.allSatisfy(\.isBlurred), "recovery timer cannot acquire hover")
recovery.pointerMoved(item: 2, position: CGPoint(x: 1, y: 0), now: 31.1)
expect(!surfaces[1].isBlurred, "unfinished scroll stream recovers without switching windows or blank hit")
recovery.scroll(.end, in: 1, now: 31.2)
expect(!surfaces[1].isBlurred, "late notification cannot reset new intentional hover")
// Both visual choices obey the same actual visibility/reveal state.
first.setStyle(gaussian: false, tint: 0.65, material: .popover)
expect(first.isBlurred && first.gaussian.isHidden && !first.effect.isHidden, "material is the active obscuring view")
first.setStyle(gaussian: true, tint: 0.65, material: .popover)
expect(first.isBlurred && !first.gaussian.isHidden && first.effect.isHidden, "Gaussian is the active obscuring view")
first.setBlurred(false)
expect(first.gaussian.isHidden && first.effect.isHidden, "intentional reveal hides both obscuring styles")
first.setBlurred(true)
expect(first.gaussian.isOpaque && first.gaussian.hitTest(.zero) == nil, "Gaussian fallback stays opaque and click-through")
// Actual Gaussian filtering of synthetic stripes; no window/view capture.
func stripeImage(alpha: UInt8 = 255) -> CGImage {
    var bytes = [UInt8]()
    for _ in 0..<16 { for x in 0..<32 {
        let value: UInt8 = x % 2 == 0 ? 0 : 255
        bytes += [value, value, value, alpha]
    } }
    let provider = CGDataProvider(data: Data(bytes) as CFData)!
    return CGImage(width: 32, height: 16, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: 128,
                   space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue),
                   provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)!
}
func pixelBytes(_ image: CGImage) -> [UInt8] {
    var bytes = [UInt8](repeating: 0, count: image.width * image.height * 4)
    bytes.withUnsafeMutableBytes { data in
        let context = CGContext(data: data.baseAddress, width: image.width, height: image.height, bitsPerComponent: 8,
                                bytesPerRow: image.width * 4, space: CGColorSpaceCreateDeviceRGB(),
                                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue)!
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
    }
    return bytes
}
let plainBlur = GaussianRenderer.render(stripeImage(), radius: 5, tint: CIColor.white, tintOpacity: 0)!
let blurredBytes = pixelBytes(plainBlur)
let middle = (4..<28).map { blurredBytes[(8 * 32 + $0) * 4] }
let adjacentContrast = zip(middle, middle.dropFirst()).map { abs(Int($0.0) - Int($0.1)) }.max()!
expect(adjacentContrast < 16 && middle.min()! > 0 && middle.max()! < 255, "sharp alternating edges must become smooth, even with clamped boundary gradients")
let tintedBlur = GaussianRenderer.render(stripeImage(alpha: 0), radius: 5, tint: CIColor.white, tintOpacity: 0.65)!
let tintedBytes = pixelBytes(tintedBlur)
expect(stride(from: 3, to: tintedBytes.count, by: 4).allSatisfy { tintedBytes[$0] == 255 }, "tint layer cannot expose sharp content through output alpha")
expect(GaussianRenderer.render(stripeImage(), radius: .nan, tint: CIColor.white, tintOpacity: 0.65) == nil, "invalid blur parameters are rejected")
// Exercise the full invented-text drawing path in a generated image context.
// This renders our own NSView into memory; no screen/window pixels are read.
let sample = GaussianMessageView(text: "Invented private message\nMeet at the imaginary cafe", fontSize: 14,
                                 bubble: NSColor.systemGreen.withAlphaComponent(0.15), frame: CGRect(x: 0, y: 0, width: 300, height: 90))
let generatedSample = NSImage(size: sample.bounds.size, flipped: false) { rect in sample.draw(rect); return true }
let sampleImage = generatedSample.cgImage(forProposedRect: nil, context: nil, hints: nil)
expect(sampleImage != nil && !sample.renderFailed, "complete Gaussian text drawing succeeds without a window")
if let sampleImage = sampleImage {
    let bytes = pixelBytes(sampleImage)
    expect(stride(from: 3, to: bytes.count, by: 4).allSatisfy { bytes[$0] == 255 }, "actual message renderer leaves no transparent sharp-text holes")
}
print("\(assertions) AppKit view-tree assertions, \(failures) failures")
exit(failures == 0 ? 0 : 1)

import AppKit
import Darwin
import LabViews

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
controller.pointerMoved(item: nil, now: 0.9) // Actual pointer exit after enabling hover.
controller.pointerMoved(item: 1, now: 1)
expect(!surfaces[0].isBlurred && surfaces[1].isBlurred && surfaces[2].isBlurred, "hover reveals exactly one surface")
let identities = surfaces.map(ObjectIdentifier.init)
let effectIdentities = surfaces.map { ObjectIdentifier($0.effect) }
// Reapplying expiry or an ordinary control click must not remove other views.
controller.tick(now: 1.01)
expect(surfaces[1].isBlurred && surfaces[2].isBlurred, "unrelated items remain blurred across presentation update")
clip.onWillChange = { controller.layoutWillChange() }
clip.scroll(to: CGPoint(x: 0, y: 181))
expect(surfaces.allSatisfy(\.isBlurred), "bounds change revokes reveal without a polling tick")
controller.pointerMoved(item: 2, now: 1.02)
expect(surfaces.allSatisfy(\.isBlurred), "stationary pointer cannot reveal another scrolled item")
controller.pointerMoved(item: nil, now: 1.03)
controller.pointerMoved(item: 2, now: 1.04)
expect(!surfaces[1].isBlurred, "exit and reentry may reveal after movement")
controller.beginScroll(1)
controller.pointerMoved(item: nil, now: 1.05)
controller.pointerMoved(item: 3, now: 1.06)
expect(surfaces.allSatisfy(\.isBlurred), "pointer events during live scroll cannot reveal")
controller.endScroll(1)
controller.pointerMoved(item: 3, now: 1.07)
expect(surfaces.allSatisfy(\.isBlurred), "scroll end does not auto-reveal under pointer")
controller.pointerMoved(item: nil, now: 1.08)
controller.pointerMoved(item: 3, now: 1.09)
expect(!surfaces[2].isBlurred, "new intentional hover after live scroll")
controller.setFocus(false)
expect(surfaces.allSatisfy(\.isBlurred), "visible inactive content stays blurred")
controller.setFocus(true)
controller.pointerMoved(item: 3, now: 1.1)
expect(surfaces.allSatisfy(\.isBlurred), "focus regain does not renew reveal")
controller.beginScroll(1); controller.beginScroll(2); controller.endScroll(1)
controller.pointerMoved(item: nil, now: 2)
controller.pointerMoved(item: 1, now: 2.01)
expect(surfaces.allSatisfy(\.isBlurred), "overlapping scroll activity remains blocked until all sources end")
controller.endScroll(2)
controller.pointerMoved(item: nil, now: 2.02)
controller.pointerMoved(item: 1, now: 2.03)
expect(!surfaces[0].isBlurred, "all scroll sources ended plus explicit reentry permits reveal")
controller.layoutWillChange()
// No timer is invoked throughout this rapid fractional/reversing scroll burst.
for y in [0.0, 0.5, 71.25, 400.0, 105.75, 999.0, 10.0] {
    clip.scroll(to: CGPoint(x: 0, y: y))
    for surface in surfaces {
        expect(surface.convert(surface.bounds, to: clip) == surface.effect.convert(surface.effect.bounds, to: clip), "content/blur share fractional scroll transform")
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
expect(first.effect.frame == first.bounds, "resizing content resizes its blur in the same tree")
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
print("\(assertions) AppKit view-tree assertions, \(failures) failures")
exit(failures == 0 ? 0 : 1)

import AppKit
import GeometryAnalysis
import IntegrationCore
var count = 0
var failures = 0
func check(_ condition: @autoclosure () -> Bool, _ message: String) {
    count += 1
    if !condition() { failures += 1; print("FAIL: \(message)") }
}
// Generated in memory only. No window, screenshot, file or real chat is used.
let generated = NSImage(size: NSSize(width: 900, height: 700), flipped: false) { rect in
    NSColor.white.setFill(); rect.fill()
    let attributes: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 24), .foregroundColor: NSColor.black]
    ("Contact Alpha" as NSString).draw(at: NSPoint(x: 90, y: 590), withAttributes: attributes)
    ("Invented preview content" as NSString).draw(at: NSPoint(x: 90, y: 550), withAttributes: attributes)
    ("Synthetic conversation message" as NSString).draw(at: NSPoint(x: 430, y: 450), withAttributes: attributes)
    // A photo-shaped message has private pixels but no text. Text detection alone cannot cover it.
    NSColor(calibratedRed: 0.1, green: 0.5, blue: 0.8, alpha: 1).setFill()
    NSBezierPath(roundedRect: NSRect(x: 440, y: 170, width: 320, height: 190), xRadius: 15, yRadius: 15).fill()
    return true
}
guard let image = generated.cgImage(forProposedRect: nil, context: nil, hints: nil) else { fatalError("Synthetic image unavailable") }
do {
    let boxes = try TextGeometry.rectangles(in: image)
    for (region, label) in [(CGRect(x: 85,y: 580,width: 250,height: 45), "name"),
                            (CGRect(x: 85,y: 540,width: 320,height: 45), "preview"),
                            (CGRect(x: 425,y: 440,width: 420,height: 45), "message")] {
        let pixels = region.applying(CGAffineTransform(scaleX: CGFloat(image.width) / 900, y: CGFloat(image.height) / 700))
        check(boxes.contains { $0.intersects(pixels) }, "local text geometry detects generated \(label)")
    }
    check(boxes.allSatisfy { $0.minX >= 0 && $0.minY >= 0 && $0.maxX <= CGFloat(image.width) && $0.maxY <= CGFloat(image.height) }, "geometry stays in image coordinates")
    print("Detected \(boxes.count) text rectangles; semantic roles are not supplied by this API.")
    let media = CGRect(x: 440,y: 170,width: 320,height: 190).applying(CGAffineTransform(scaleX: CGFloat(image.width) / 900, y: CGFloat(image.height) / 700))
    print("Text geometry covers media message: \(boxes.contains { $0.contains(media) })")
} catch { check(false, "on-device geometry request failed: \(error)") }
let interface = NSImage(size: NSSize(width: 900,height: 700), flipped: false) { rect in
    NSColor.white.setFill(); rect.fill()
    let font: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 26), .foregroundColor: NSColor.black]
    ("Chats" as NSString).draw(at: NSPoint(x: 30,y: 640), withAttributes: font)
    ("Search" as NSString).draw(at: NSPoint(x: 180,y: 585), withAttributes: font)
    ("Type a message" as NSString).draw(at: NSPoint(x: 480,y: 30), withAttributes: font)
    ("Invented private content" as NSString).draw(at: NSPoint(x: 450,y: 390), withAttributes: font)
    ("Message" as NSString).draw(at: NSPoint(x: 500,y: 300), withAttributes: font)
    return true
}
if let input = interface.cgImage(forProposedRect: nil, context: nil, hints: nil) {
    do {
        let anchors = try UIAnchorRecognition.anchors(in: input)
        check(anchors.contains { $0.kind == .chats }, "on-device OCR finds navigation anchor")
        check(anchors.contains { $0.kind == .search }, "on-device OCR finds search anchor")
        check(anchors.filter { $0.kind == .composer }.count == 1, "composer anchor excludes matching word inside message body")
        check(anchors.count == 3, "only whitelisted UI categories are returned")
        print("Recognized \(anchors.count) whitelisted UI anchors; no recognized strings emitted.")
    } catch { check(false, "local OCR anchor investigation failed") }
} else { check(false, "generated UI fixture unavailable") }
let testAnchors = [UIAnchor(kind: .search,bounds: CGRect(x: 90,y: 630,width: 120,height: 20)),UIAnchor(kind: .composer,bounds: CGRect(x: 420,y: 25,width: 120,height: 20))]
let testText = [CGRect(x: 100,y: 550,width: 110,height: 20),CGRect(x: 100,y: 520,width: 200,height: 18),CGRect(x: 440,y: 450,width: 240,height: 20)]
let native = NativeLayoutDetector.plan(width: 900,height: 700,divider: 360,anchors: testAnchors,text: testText,rectangles: [CGRect(x: 450,y: 150,width: 250,height: 160)])
check(native != nil,"anchored layout yields experimental localized regions")
if let native = native {
    check(native.regions.contains { $0.category == .sidebarPreview && $0.bounds.contains(CGPoint(x: 110,y: 530)) },"sidebar preview is localized below row name")
    check(native.regions.contains { $0.category == .contactName && $0.bounds.contains(CGPoint(x: 110,y: 560)) },"name gets separate category")
    check(native.regions.contains { $0.category == .avatar },"row-derived avatar category exists")
    check(native.regions.contains { $0.category == .conversationMessage && $0.bounds.contains(CGPoint(x: 500,y: 200)) },"media rectangle included independently of text")
    check(native.regions.filter { $0.category == .conversationMessage }.allSatisfy { !$0.bounds.intersects(testAnchors[1].bounds) },"composer excluded")
}
check(NativeLayoutDetector.plan(width: 900,height: 700,divider: nil,anchors: testAnchors,text: testText,rectangles: []) == nil,"ambiguous divider rejected")
check(NativeLayoutDetector.plan(width: 900,height: 700,divider: 360,anchors: [],text: testText,rectangles: []) == nil,"no guessed layout without anchors")
print("\(count) geometry probe assertions, \(failures) failures")
if failures > 0 { exit(1) }

import Foundation
import CoreGraphics
import IntegrationCore
import NativeRendering
var count = 0, failures = 0
func check(_ value: @autoclosure () -> Bool, _ message: String) {
    count += 1; if !value() { failures += 1; print("FAIL: \(message)") }
}
let width = 320, height = 240
let space = CGColorSpaceCreateDeviceRGB()
let bitmap = CGImageAlphaInfo.premultipliedLast.rawValue
func pixels(_ image: CGImage) -> [UInt8] {
    var data = [UInt8](repeating: 0, count: width * height * 4)
    data.withUnsafeMutableBytes { bytes in
        let c = CGContext(data: bytes.baseAddress, width: width, height: height, bitsPerComponent: 8,
                          bytesPerRow: width * 4, space: space, bitmapInfo: bitmap)!
        c.draw(image, in: CGRect(x: 0,y: 0,width: width,height: height))
    }; return data
}
let c = CGContext(data: nil, width: width,height: height,bitsPerComponent: 8,bytesPerRow: width*4,space: space,bitmapInfo: bitmap)!
c.setFillColor(CGColor(gray: 0.95,alpha: 1)); c.fill(CGRect(x: 0,y: 0,width: width,height: height))
for x in stride(from: 0,to: width,by: 4) {
    c.setFillColor(CGColor(gray: 0.05,alpha: 1)); c.fill(CGRect(x: x,y: 0,width: 2,height: height))
}
let source = c.makeImage()!, original = pixels(source)
let regions = BlurCategory.allCases.enumerated().map { index, category in
    DetectedRegion(id: UInt64(index+1),category: category,bounds: CGRect(x: index*80+10,y: 40,width: 60,height: 160))
}
for bits in 1..<16 {
    let settings = BlurSettings(sidebarPreviews: bits & 1 != 0,conversationMessages: bits & 2 != 0,
                               names: bits & 4 != 0,avatars: bits & 8 != 0)
    if let image = FrameCompositor.render(source,plan: RegionPlan(.ready,regions: regions),settings: settings) {
        let result = pixels(image)
        check(stride(from: 3,to: result.count,by: 4).allSatisfy { result[$0] == 255 },"opaque composed frame \(bits)")
        for (index, category) in BlurCategory.allCases.enumerated() {
            let offset = (120*width + index*80+40)*4
            check((Array(result[offset..<offset+3]) != Array(original[offset..<offset+3])) == settings.isEnabled(category),"independent category \(bits)/\(index)")
        }
        check(Array(result[0..<4]) == Array(original[0..<4]),"unrequested UI unchanged")
    } else { check(false,"composite produced for category combination \(bits)") }
}
let hover = BlurSettings(names: true,avatars: true,sidebarHover: true,conversationHover: true)
for id: UInt64 in 1...4 {
    if let image = FrameCompositor.render(source,plan: RegionPlan(.ready,regions: regions),settings: hover,reveal: id) {
        let result = pixels(image), index = Int(id)-1, offset = (120*width+index*80+40)*4
        check((Array(result[offset..<offset+3]) == Array(original[offset..<offset+3])) == (id<=2),"identity is never revealed \(id)")
    } else { check(false,"hover composite exists") }
}
for tint in [0.4,0.65,0.9] {
    var s = BlurSettings(); s.tint = tint
    check(FrameCompositor.render(source,plan: RegionPlan(.ready,regions: regions),settings: s) != nil,"tint supported \(tint)")
}
check(FrameCompositor.render(source,plan: RegionPlan(.experimental,regions: regions),settings: BlurSettings()) != nil,"explicit experimental candidate can render without claiming supported layout")
for state in [RegionValidationState.unsupported,.mismatch,.stale,.invalid,.disabled] {
    check(FrameCompositor.render(source,plan: RegionPlan(state,regions: regions),settings: BlurSettings()) == nil,"no sharp fallback for rejected plan")
}
let outside = DetectedRegion(id: 1,category: .conversationMessage,bounds: CGRect(x: -1,y: 0,width: 50,height: 50))
check(FrameCompositor.render(source,plan: RegionPlan(.ready,regions: [outside]),settings: BlurSettings()) == nil,"invalid crop fails whole frame")
let green = CGContext(data: nil,width: width,height: height,bitsPerComponent: 8,bytesPerRow: width*4,space: space,bitmapInfo: bitmap)!
green.setFillColor(CGColor(red: 0.55,green: 0.88,blue: 0.60,alpha: 1)); green.fill(CGRect(x: 0,y: 0,width: width,height: height))
green.setFillColor(CGColor(gray: 0,alpha: 1)); green.fill(CGRect(x: 20,y: 110,width: 40,height: 4))
if let image = FrameCompositor.render(green.makeImage()!,plan: RegionPlan(.experimental,regions: [regions[0]]),settings: BlurSettings()) {
    let bytes = pixels(image),offset = (120*width+40)*4
    check(Int(bytes[offset+1])-Int(bytes[offset]) > 60,"tint preserves green bubble hierarchy instead of a white rectangle")
    check(bytes[offset] < 180,"tint follows local bubble background")
} else { check(false,"bubble color fixture renders") }
let overlap = [DetectedRegion(id: 1001,category: .conversationMessage,bounds: CGRect(x: 10,y: 40,width: 140,height: 160)),DetectedRegion(id: 1002,category: .contactName,bounds: CGRect(x: 70,y: 40,width: 30,height: 160))]
if let image = FrameCompositor.render(source,plan: RegionPlan(.experimental,regions: overlap),settings: BlurSettings(names: true,conversationHover: true),reveal: 1001) {
    let bytes = pixels(image),offset = (120*width+80)*4
    check(Array(bytes[offset..<offset+3]) != Array(original[offset..<offset+3]),"message hover cannot reveal overlapping identity")
} else { check(false,"overlap fixture renders") }
print("\(count) compositor assertions, \(failures) failures")
if failures > 0 { exit(1) }

import AppKit
import ScreenCaptureKit
import CoreMedia
import CoreImage
import CoreVideo
import CaptureAdapter
import IntegrationCore
import DesktopPipeline
var total = 0,failures = 0
func check(_ value: @autoclosure () -> Bool,_ name: String) { total += 1;if !value(){failures += 1;print("FAIL: \(name)")} }
let fixture = NSImage(size: NSSize(width: 900,height: 700),flipped: false) { rect in
    NSColor(calibratedWhite:0.04,alpha:1).setFill();rect.fill()
    NSColor(calibratedWhite:0.18,alpha:1).setFill();NSRect(x:180,y:0,width:270,height:700).fill()
    NSColor(calibratedWhite:0.10,alpha:1).setFill();NSRect(x:0,y:0,width:180,height:700).fill()
    let text: [NSAttributedString.Key:Any] = [.font:NSFont.systemFont(ofSize:22),.foregroundColor:NSColor.white]
    ("Archived" as NSString).draw(at:NSPoint(x:280,y:640),withAttributes:text)
    ("Fixture Alpha" as NSString).draw(at:NSPoint(x:250,y:560),withAttributes:text)
    ("Invented message" as NSString).draw(at:NSPoint(x:250,y:530),withAttributes:text)
    return true
}
let image = fixture.cgImage(forProposedRect:nil,context:nil,hints:nil)!
var pixel: CVPixelBuffer?
check(CVPixelBufferCreate(kCFAllocatorDefault,image.width,image.height,kCVPixelFormatType_32BGRA,nil,&pixel) == kCVReturnSuccess,"real generated pixel buffer")
CVPixelBufferLockBaseAddress(pixel!,[])
let cg = CGContext(data:CVPixelBufferGetBaseAddress(pixel!),width:image.width,height:image.height,bitsPerComponent:8,bytesPerRow:CVPixelBufferGetBytesPerRow(pixel!),space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue)!
cg.draw(image,in:CGRect(x:0,y:0,width:image.width,height:image.height))
CVPixelBufferUnlockBaseAddress(pixel!,[])
var format: CMVideoFormatDescription?
CMVideoFormatDescriptionCreateForImageBuffer(allocator:kCFAllocatorDefault,imageBuffer:pixel!,formatDescriptionOut:&format)
var timing = CMSampleTimingInfo(duration:.invalid,presentationTimeStamp:CMTime(seconds:10,preferredTimescale:600),decodeTimeStamp:.invalid)
var sample: CMSampleBuffer?
CMSampleBufferCreateReadyWithImageBuffer(allocator:kCFAllocatorDefault,imageBuffer:pixel!,formatDescription:format!,sampleTiming:&timing,sampleBufferOut:&sample)
let attachments = CMSampleBufferGetSampleAttachmentsArray(sample!,createIfNecessary:true)! as NSArray
let dictionary = attachments[0] as! NSMutableDictionary
dictionary[SCStreamFrameInfo.status.rawValue] = SCFrameStatus.started.rawValue
let decoded = FrameSampleDecoder.decode(sample!)
check(decoded.kind == .image && decoded.pixels != nil && decoded.capturedAt == 10,"actual started sample decoded through production receiver")
dictionary[SCStreamFrameInfo.status.rawValue] = SCFrameStatus.stopped.rawValue
check(FrameSampleDecoder.decode(sample!).kind == .unavailable,"actual stopped sample cannot become pixels")
dictionary[SCStreamFrameInfo.status.rawValue] = SCFrameStatus.started.rawValue
let receivedImage = FrameSampleDecoder.decode(sample!).image(context:CIContext(options:[.cacheIntermediates:false]))
check(receivedImage != nil,"decoded real buffer converts through production image path")
// Real attachment transforms, including Retina and padded surfaces.
let transformContext = CIContext(options:[.cacheIntermediates:false])
func metadata(_ rect:CGRect,_ scale:Double,_ content:Double) {
    dictionary[SCStreamFrameInfo.contentRect.rawValue] = rect.dictionaryRepresentation
    dictionary[SCStreamFrameInfo.scaleFactor.rawValue] = scale
    dictionary[SCStreamFrameInfo.contentScale.rawValue] = content
}
metadata(CGRect(x:0,y:0,width:450,height:350),2,1)
let retina = FrameSampleDecoder.decode(sample!).normalizedImage(context:transformContext,windowSize:CGSize(width:450,height:350))
check(retina?.width == 900 && retina?.height == 700,"Retina attachment transform keeps exact pixels")
metadata(CGRect(x:10,y:20,width:880,height:660),1,1)
let inset = FrameSampleDecoder.decode(sample!).normalizedImage(context:transformContext,windowSize:CGSize(width:880,height:660))
check(inset?.width == 880 && inset?.height == 660,"nonzero padded content rect is cropped before analysis")
check(FrameSampleDecoder.decode(sample!).normalizedImage(context:transformContext,windowSize:CGSize(width:900,height:700)) == nil,"wrong content/window transform rejects image")
metadata(CGRect(x:0,y:0,width:image.width+1,height:image.height),1,1)
check(FrameSampleDecoder.decode(sample!).normalizedImage(context:transformContext,windowSize:CGSize(width:image.width+1,height:image.height)) == nil,"content outside buffer rejects image")
metadata(CGRect(x:0,y:0,width:900,height:700),1,0)
check(FrameSampleDecoder.decode(sample!).normalizedImage(context:transformContext,windowSize:CGSize(width:900,height:700)) == nil,"zero content scale rejects image")
metadata(CGRect(x:0,y:0,width:900,height:700),1,1)
let settings = BlurSettings()
let session = CaptureSession(continuous:true)
let token = session.request(settings:settings,now:10)!
let selected = SelectionDescriptor(windowID:42,pid:123,generation:1,bundleIdentifier:"net.whatsapp.WhatsApp",singleWindow:true,trusted:true)
check(session.accept(selected,token:token,now:10),"injected authenticated fixture selection")
check(session.consumeFrame(token:token,capturedAt:10,now:10.1,width:image.width,height:image.height,targetStillTrusted:true),"frame admission")
let binding = FrameBinding(session:token,sequence:1,windowID:42,processID:123,processGeneration:1,capturedAt:10,width:image.width,height:image.height,scale:2,windowFrame:CGRect(x:0,y:0,width:900,height:700))
let source = CapturedWindowFrame(image:receivedImage ?? image,binding:binding)
let processed = FrameProcessor.process(source,settings:settings)
check(processed != nil,"real detector and compositor produce localized processed image")
if let processed = processed {
    print("Synthetic cold \(image.width)x\(image.height): analysis=\(Int(processed.analysisMilliseconds))ms Gaussian=\(Int(processed.renderMilliseconds))ms")
    check(processed.plan.regions.contains { $0.category == .sidebarPreview },"actual OCR/edge sidebar regions")
    check(processed.image.width == image.width && processed.image.height == image.height,"processed frame matches input dimensions")
    func rgba(_ input: CGImage) -> [UInt8] {
        var bytes = [UInt8](repeating:0,count:input.width*input.height*4)
        bytes.withUnsafeMutableBytes { storage in
            let c = CGContext(data:storage.baseAddress,width:input.width,height:input.height,bitsPerComponent:8,bytesPerRow:input.width*4,space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue)!
            c.draw(input,in:CGRect(x:0,y:0,width:input.width,height:input.height))
        };return bytes
    }
    let before = rgba(source.image),after = rgba(processed.image)
    check(zip(before,after).contains { abs(Int($0)-Int($1)) > 20 },"localized Gaussian pixels really change through the receiver pipeline")
    check((0..<3).allSatisfy { abs(Int(before[$0])-Int(after[$0])) <= 2 },"untargeted control corner remains unchanged")
    check(stride(from:3,to:after.count,by:4).allSatisfy { after[$0] == 255 },"published image is opaque")
    let coordinator = FramePipeline()
    var installations = 0
    let revision = coordinator.revision
    check(coordinator.deliver(processed,revision:revision,currentWindow:binding.windowFrame,now:10.2,install:{ _ in installations += 1;return true }) == .displayed && installations == 1,"actual pipeline coordinator installs before reporting displayed")
    coordinator.reset()
    check(coordinator.deliver(processed,revision:revision,currentWindow:binding.windowFrame,now:10.2,install:{ _ in installations += 1;return true }) == .rejected && installations == 1,"old result never reaches presentation after stop")
    check(coordinator.deliver(processed,revision:coordinator.revision,currentWindow:binding.windowFrame,now:10.2,install:{ _ in false }) == .prepared,"declined surface never reports rendering")
    let gate = PublicationGate()
    check(gate.prepare(revision:gate.revision,frame:processed.source.binding,currentWindow:binding.windowFrame,now:10.2),"settings-focus preparation accepted")
    gate.reset()
    check(!gate.prepare(revision:gate.revision-1,frame:binding,currentWindow:binding.windowFrame,now:10.2),"stop prevents prepared-result revival")
}
check(FrameProcessor.process(source,settings:BlurSettings(sidebarPreviews:false,conversationMessages:true)) == nil,"missing requested conversation never emits a raw overlay")
let trace = StartupTrace()
for n in 0..<100 { trace.record(.analyzing,now:Double(n)) }
check(trace.entries.count == 32 && trace.entries.first?.time == 68,"trace bounded to32 metadata entries")
trace.record(.failed,now:.nan)
check(trace.entries.count == 32 && trace.entries.last?.time == 99,"nonfinite diagnostics rejected")
// Harmless repeatable processing timings; these are not capture-to-display/native measurements.
for size in [CGSize(width:900,height:700),CGSize(width:1800,height:1400)] {
    let c = CGContext(data:nil,width:Int(size.width),height:Int(size.height),bitsPerComponent:8,bytesPerRow:Int(size.width)*4,space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue)!
    c.draw(image,in:CGRect(origin:.zero,size:size));let invented = c.makeImage()!
    var times:[Double] = []
    for _ in 0..<5 {
        var scaled = binding;scaled.width = invented.width;scaled.height = invented.height
        let result = autoreleasepool { FrameProcessor.process(CapturedWindowFrame(image:invented,binding:scaled),settings:settings) }
        check(result != nil,"benchmark still processes through real detector and compositor")
        if let result = result { times.append(result.analysisMilliseconds+result.renderMilliseconds) }
    }
    if !times.isEmpty { print("Synthetic warm \(invented.width)x\(invented.height): median=\(Int(times.sorted()[times.count/2]))ms max=\(Int(times.max()!))ms (5 frames; no live capture or presentation)") }
}
// The real automatic construction path must retain all saved settings on attach/reconnect.
let custom = BlurSettings(sidebarPreviews:false,conversationMessages:true,names:true,avatars:true,sidebarHover:true,conversationHover:true,tint:0.83)
for _ in 0..<2 {
    let coordinator = AutomaticController.makeEngine(settings:custom)
    check(coordinator.settings.names && coordinator.settings.avatars,"automatic attachment/reconnection honors saved identity blur")
    check(!coordinator.settings.sidebarPreviews && coordinator.settings.conversationMessages && coordinator.settings.conversationHover && coordinator.settings.tint == 0.83,"automatic construction honors category/hover/tint choices")
    if let prepared = processed {
        coordinator.cachePrepared(prepared)
        check(coordinator.hasPreparedImage,"actual coordinator cached a prepared image")
        coordinator.discardPublication()
        check(!coordinator.hasPreparedImage,"rejected/expired coordinator publication cannot be restored on a timer")
    }

}
print("\(total) integrated harness assertions, \(failures) failures")
if failures > 0 { exit(1) }

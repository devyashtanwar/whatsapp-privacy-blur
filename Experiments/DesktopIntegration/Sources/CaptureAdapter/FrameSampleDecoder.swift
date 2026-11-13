import CoreMedia
import CoreImage
import CoreVideo
import ScreenCaptureKit
public struct DecodedWindowSample {
    public let kind: FrameSampleKind
    public let status: Int?
    public let pixels: CVPixelBuffer?
    public let capturedAt: Double?
    public let contentRect:CGRect?
    public let scaleFactor:Double?
    public let contentScale:Double?
    public func normalizedImage(context:CIContext,windowSize:CGSize) -> CGImage? {
        guard let rect = contentRect,let factor = scaleFactor,let content = contentScale,
              factor.isFinite,(1...4).contains(factor),content.isFinite,content > 0,content <= 4,
              windowSize.width.isFinite,windowSize.height.isFinite,windowSize.width > 0,windowSize.height > 0,
              rect.minX.isFinite,rect.minY.isFinite,rect.width.isFinite,rect.height.isFinite,rect.width > 0,rect.height > 0,
              abs(rect.width/content-windowSize.width) <= 1,abs(rect.height/content-windowSize.height) <= 1,
              kind == .image,let pixels = pixels,let time = capturedAt,time.isFinite,time >= 0 else { return nil }
        let image = CIImage(cvPixelBuffer:pixels)
        // Attachment contentRect is in surface points, origin at top left.
        let crop = CGRect(x:rect.minX*factor,y:image.extent.height-rect.maxY*factor,width:rect.width*factor,height:rect.height*factor).integral
        guard image.extent.contains(crop),crop.width > 0,crop.height > 0 else { return nil }
        return context.createCGImage(image.cropped(to:crop),from:crop)
    }
    public func image(context: CIContext) -> CGImage? {
        guard kind == .image,let pixels = pixels,let time = capturedAt,time.isFinite,time >= 0 else { return nil }
        let image = CIImage(cvPixelBuffer:pixels)
        return context.createCGImage(image,from:image.extent)
    }
}
public enum FrameSampleDecoder {
    public static func decode(_ sample: CMSampleBuffer) -> DecodedWindowSample {
        guard let attachments = CMSampleBufferGetSampleAttachmentsArray(sample,createIfNecessary:false) as? [[SCStreamFrameInfo:Any]],
              let raw = attachments.first?[.status] as? Int,let status = SCFrameStatus(rawValue:raw) else {
            return .init(kind:.ignored,status:nil,pixels:nil,capturedAt:nil,contentRect:nil,scaleFactor:nil,contentScale:nil)
        }
        let pixels = CMSampleBufferGetImageBuffer(sample)
        let kind = FrameSamplePolicy.classify(status,sampleValid:CMSampleBufferIsValid(sample),dataReady:CMSampleBufferDataIsReady(sample),hasImage:pixels != nil)
        let time = CMTimeGetSeconds(CMSampleBufferGetPresentationTimeStamp(sample))
        if kind == .image && (!time.isFinite || time < 0) { return .init(kind:.ignored,status:raw,pixels:nil,capturedAt:nil,contentRect:nil,scaleFactor:nil,contentScale:nil) }
        let metadata = attachments.first!
        let rect = (metadata[.contentRect] as? [String:Any]).flatMap { CGRect(dictionaryRepresentation:$0 as CFDictionary) }
        return .init(kind:kind,status:raw,pixels:kind == .image ? pixels : nil,capturedAt:kind == .image ? time : nil,
                     contentRect:rect,scaleFactor:(metadata[.scaleFactor] as? NSNumber)?.doubleValue,contentScale:(metadata[.contentScale] as? NSNumber)?.doubleValue)
    }
}

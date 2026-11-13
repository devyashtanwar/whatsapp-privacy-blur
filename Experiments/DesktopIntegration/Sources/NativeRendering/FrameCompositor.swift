import CoreGraphics
import CoreImage
import IntegrationCore

/// One opaque processed image, with unchanged UI outside the requested regions.
/// The caller owns geometry validation and must publish the matching frame atomically.
public enum FrameCompositor {
    private static let context = CIContext(options: [.cacheIntermediates: false])
    public static func render(_ source: CGImage, plan: RegionPlan, settings: BlurSettings, reveal: UInt64? = nil) -> CGImage? {
        guard (plan.state == .ready || plan.state == .experimental), settings.needsCapture, source.width > 0, source.height > 0,
              source.width <= 4096, source.height <= 4096 else { return nil }
        let extent = CGRect(x: 0,y: 0,width: source.width,height: source.height)
        guard plan.regions.allSatisfy({ valid($0.bounds, in: extent) }) else { return nil }
        let input = CIImage(cgImage: source)
        let background = CIImage(color: CIColor(red: 0.12,green: 0.13,blue: 0.14)).cropped(to: extent)
        var output = input.composited(over: background)
        // Identity is applied last, so even overlapping message reveal cannot remove it.
        let regions = plan.regions.sorted { a,b in rank(a.category) < rank(b.category) }
        for region in regions where settings.isEnabled(region.category) {
            if region.id == reveal && settings.permitsHover(region.category) { continue }
            let bounds = region.bounds.integral
            guard let crop = context.createCGImage(input.cropped(to: bounds),from: bounds) else { return nil }
            // Corner samples follow the local bubble/background colour instead of painting a white/black block.
            var channels = [CGFloat](repeating: 0,count: 3)
            for point in [CGPoint(x: bounds.minX,y: bounds.minY),CGPoint(x: bounds.maxX-1,y: bounds.minY),
                          CGPoint(x: bounds.minX,y: bounds.maxY-1),CGPoint(x: bounds.maxX-1,y: bounds.maxY-1)] {
                var sample = [UInt8](repeating: 0,count: 4)
                context.render(output,toBitmap: &sample,rowBytes: 4,bounds: CGRect(origin: point,size: CGSize(width: 1,height: 1)),format: .RGBA8,colorSpace: CGColorSpaceCreateDeviceRGB())
                for channel in 0..<3 { channels[channel] += CGFloat(sample[channel])/1020 }
            }
            let tint = CIColor(red: channels[0],green: channels[1],blue: channels[2],alpha: 1)
            let radius = min(64,max(18,Double(source.width)/80))
            guard let blurred = GaussianRenderer.render(crop,radius: radius,tint: tint,tintOpacity: settings.tint) else { return nil }
            let patch = CIImage(cgImage: blurred).transformed(by: CGAffineTransform(translationX: bounds.minX,y: bounds.minY))
            output = patch.composited(over: output)
        }
        return context.createCGImage(output,from: extent)
    }
    private static func rank(_ c: BlurCategory) -> Int { c == .contactName || c == .avatar ? 1 : 0 }
    private static func valid(_ r: CGRect,in extent: CGRect) -> Bool {
        r.minX.isFinite && r.minY.isFinite && r.width.isFinite && r.height.isFinite && r.width > 0 && r.height > 0 && extent.contains(r.integral)
    }
}

import AppKit
import CoreImage

/// Filters pixels generated from the lab's own invented content only.
public enum GaussianRenderer {
    private static let context = CIContext(options: [.useSoftwareRenderer: true])
    public static func render(_ input: CGImage, radius: Double, tint: CIColor, tintOpacity: Double, context suppliedContext:CIContext? = nil) -> CGImage? {
        guard radius.isFinite, radius > 0, radius <= 64, tintOpacity.isFinite, (0...1).contains(tintOpacity),
              input.width <= 4096, input.height <= 4096 else { return nil }
        let source = CIImage(cgImage: input)
        // Opaque background prevents alpha from admitting sharp underlying text.
        let background = CIImage(color: CIColor(red: tint.red, green: tint.green, blue: tint.blue, alpha: 1)).cropped(to: source.extent)
        let opaque = source.composited(over: background)
        let blurred = opaque.clampedToExtent().applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: radius]).cropped(to: source.extent)
        let veil = CIImage(color: CIColor(red: tint.red, green: tint.green, blue: tint.blue, alpha: CGFloat(tintOpacity))).cropped(to: source.extent)
        return (suppliedContext ?? context).createCGImage(veil.composited(over: blurred), from: source.extent)
    }
}

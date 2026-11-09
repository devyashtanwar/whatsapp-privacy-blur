import CoreGraphics
import Vision

/// Geometry only: never requests recognition, produces strings or stores input images.
public enum TextGeometry {
    public static func rectangles(in image: CGImage) throws -> [CGRect] {
        guard image.width > 0, image.height > 0, image.width <= 4096, image.height <= 4096 else { return [] }
        let request = VNDetectTextRectanglesRequest()
        request.reportCharacterBoxes = false
        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        try handler.perform([request])
        let width = CGFloat(image.width), height = CGFloat(image.height)
        return (request.results ?? []).compactMap { observation in
            let b = observation.boundingBox
            guard b.minX >= 0, b.minY >= 0, b.maxX <= 1, b.maxY <= 1, b.width > 0, b.height > 0 else { return nil }
            return CGRect(x: b.minX * width, y: b.minY * height, width: b.width * width, height: b.height * height)
        }
    }
}

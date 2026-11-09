import CoreGraphics
import Vision
import Foundation

public enum UIAnchorKind: String { case chats, archived, search, composer }
public struct UIAnchor {
    public let kind: UIAnchorKind
    public let bounds: CGRect
    public init(kind: UIAnchorKind, bounds: CGRect) { self.kind = kind; self.bounds = bounds }
}
/// Research-only candidate matches, not proof of layout/semantic roles.
/// The result contains only hardcoded categories/bounds. Strings remain local to the request.
public enum UIAnchorRecognition {
    public static func anchors(in image: CGImage) throws -> [UIAnchor] {
        guard image.width > 0, image.height > 0, image.width <= 4096, image.height <= 4096 else { return [] }
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["en-US"]
        request.usesLanguageCorrection = false
        request.automaticallyDetectsLanguage = false
        try VNImageRequestHandler(cgImage: image, options: [:]).perform([request])
        return (request.results ?? []).compactMap { observation in
            guard let candidate = observation.topCandidates(1).first, candidate.confidence >= 0.6 else { return nil }
            let label = candidate.string.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let b = observation.boundingBox
            guard b.minX >= 0, b.minY >= 0, b.maxX <= 1, b.maxY <= 1, b.width > 0, b.height > 0 else { return nil }
            let kind: UIAnchorKind
            switch label {
            case "chats" where b.midX <= 0.5 && b.midY >= 0.75: kind = .chats
            case "archived" where b.midX <= 0.5 && b.midY >= 0.75: kind = .archived
            case "search", "search or start a new chat":
                guard b.midX <= 0.55 && b.midY >= 0.65 else { return nil }; kind = .search
            case "message", "type a message":
                guard b.midX >= 0.35 && b.midY <= 0.2 else { return nil }; kind = .composer
            default: return nil
            }
            return UIAnchor(kind: kind, bounds: CGRect(x: b.minX * CGFloat(image.width), y: b.minY * CGFloat(image.height),
                                                       width: b.width * CGFloat(image.width), height: b.height * CGFloat(image.height)))
        }
    }
}

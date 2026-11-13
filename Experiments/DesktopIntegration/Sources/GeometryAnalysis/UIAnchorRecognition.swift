import CoreGraphics
import Vision
import Foundation

public enum UIAnchorKind: String { case chats, archived, search, composer }
public struct UIAnchor {
    public let kind: UIAnchorKind
    public let bounds: CGRect
    public init(kind: UIAnchorKind, bounds: CGRect) { self.kind = kind; self.bounds = bounds }
}
public struct LocalTextAnalysis {
    public let anchors: [UIAnchor]
    public let text: [CGRect]
}
/// User-authorized local OCR. Only geometry/whitelisted enum labels escape the request.
/// No content strings, request objects or source images are retained by this helper.
public enum UIAnchorRecognition {
    public static func anchors(in image: CGImage) throws -> [UIAnchor] { try analyze(image).anchors }
    public static func analyze(_ image: CGImage) throws -> LocalTextAnalysis {
        guard image.width > 0, image.height > 0, image.width <= 4096, image.height <= 4096 else { return LocalTextAnalysis(anchors: [],text: []) }
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["en-US"]
        request.usesLanguageCorrection = false
        request.automaticallyDetectsLanguage = false
        try VNImageRequestHandler(cgImage: image, options: [:]).perform([request])
        var anchors: [UIAnchor] = [], text: [CGRect] = []
        for observation in request.results ?? [] {
            let b = observation.boundingBox
            guard b.minX >= 0, b.minY >= 0, b.maxX <= 1, b.maxY <= 1, b.width > 0, b.height > 0 else { continue }
            let pixels = CGRect(x: b.minX * CGFloat(image.width),y: b.minY * CGFloat(image.height),width: b.width * CGFloat(image.width),height: b.height * CGFloat(image.height))
            text.append(pixels)
            guard let candidate = observation.topCandidates(1).first, candidate.confidence >= 0.6 else { continue }
            let label = candidate.string.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let kind: UIAnchorKind
            switch label {
            case "chats" where b.midX <= 0.5 && b.midY >= 0.75: kind = .chats
            case "archived" where b.midX <= 0.5 && b.midY >= 0.75: kind = .archived
            case "search", "search or start a new chat":
                guard b.midX <= 0.55 && b.midY >= 0.65 else { continue }; kind = .search
            case "message", "type a message", "type a message…", "type a message...":
                guard b.midX >= 0.35 && b.midY <= 0.2 else { continue }; kind = .composer
            default: continue
            }
            anchors.append(UIAnchor(kind: kind,bounds: pixels))
        }
        return LocalTextAnalysis(anchors: anchors,text: text)
    }
}

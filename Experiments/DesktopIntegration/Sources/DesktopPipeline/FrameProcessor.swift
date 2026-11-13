import Foundation
import CoreGraphics
import CaptureAdapter
import IntegrationCore
import GeometryAnalysis
import NativeRendering
public struct ProcessedWindowFrame {
    public let image: CGImage
    public var source: CapturedWindowFrame
    public let plan: RegionPlan
    public let conversationAvailable: Bool
    public let analysisMilliseconds:Double
    public let renderMilliseconds:Double
}
/// Same-frame processing shared by the real coordinator and generated-buffer harness.
public enum FrameProcessor {
    public static func process(_ frame: CapturedWindowFrame,settings: BlurSettings) -> ProcessedWindowFrame? {
        let begin = ProcessInfo.processInfo.systemUptime
        guard settings.needsCapture,frame.image.width == frame.binding.width,frame.image.height == frame.binding.height,
              let detection = try? NativeLayoutDetector.detect(frame.image),
              detection.regions.contains(where:{settings.isEnabled($0.category)}) else { return nil }
        let analyzed = ProcessInfo.processInfo.systemUptime
        let plan = RegionPlan(.experimental,regions:detection.regions)
        guard let image = FrameCompositor.render(frame.image,plan:plan,settings:settings) else { return nil }
        return ProcessedWindowFrame(image:image,source:frame,plan:plan,conversationAvailable:detection.conversationAvailable,analysisMilliseconds:(analyzed-begin)*1000,renderMilliseconds:(ProcessInfo.processInfo.systemUptime-analyzed)*1000)
    }
}

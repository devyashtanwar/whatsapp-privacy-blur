import ScreenCaptureKit
import CoreVideo
import CoreMedia
public enum CaptureConfiguration {
    public static func make(width: Double, height: Double) -> SCStreamConfiguration? {
        guard width.isFinite, height.isFinite, width > 0, height > 0, width <= 4096, height <= 4096 else { return nil }
        let configuration = SCStreamConfiguration()
        configuration.width = Int(ceil(width)); configuration.height = Int(ceil(height))
        configuration.queueDepth = 2
        configuration.minimumFrameInterval = CMTime(value: 1, timescale: 30)
        configuration.pixelFormat = kCVPixelFormatType_32BGRA
        configuration.showsCursor = false
        configuration.ignoreShadowsSingleWindow = true
        configuration.includeChildWindows = false
        configuration.scalesToFit = false
        configuration.capturesAudio = false
        configuration.captureMicrophone = false
        return configuration
    }
}

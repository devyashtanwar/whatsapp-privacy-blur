import ScreenCaptureKit
public enum FrameSampleKind: String { case image, unchanged, unavailable, ignored }
/// Metadata status is separate from whether a usable image accompanies it.
public enum FrameSamplePolicy {
    public static func classify(_ status: SCFrameStatus,sampleValid: Bool,dataReady: Bool,hasImage: Bool) -> FrameSampleKind {
        guard sampleValid else { return .ignored }
        if (status == .complete || status == .started) && dataReady && hasImage { return .image }
        if status == .idle { return .unchanged }
        if status == .blank || status == .suspended || status == .stopped { return .unavailable }
        return .ignored
    }
}

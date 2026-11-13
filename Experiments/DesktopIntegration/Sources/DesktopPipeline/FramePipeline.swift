import CoreGraphics
import IntegrationCore
public enum FrameDelivery { case rejected, prepared, displayed }
/// Shared production delivery coordinator. Prepared pixels are not a displayed surface.
public final class FramePipeline {
    private let gate = PublicationGate()
    public var revision: UInt64 { gate.revision }
    public init() {}
    public func reset() { gate.reset() }
    public func deliver(_ frame: ProcessedWindowFrame,revision: UInt64,currentWindow: CGRect?,now: Double,install: (ProcessedWindowFrame)->Bool) -> FrameDelivery {
        guard gate.prepare(revision:revision,frame:frame.source.binding,currentWindow:currentWindow,now:now) else { return .rejected }
        return install(frame) ? .displayed : .prepared
    }
}

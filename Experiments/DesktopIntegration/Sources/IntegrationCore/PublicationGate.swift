import Foundation
import CoreGraphics
/// A completed worker may not publish after settings/stop/identity/window changes.
public final class PublicationGate {
    public private(set) var revision: UInt64 = 1
    private var sequence: UInt64 = 0
    public init() {}
    public func reset() { revision &+= 1; sequence = 0 }
    public func accept(revision: UInt64,frame: FrameBinding,currentWindow: CGRect?,frontmost: Bool,now: TimeInterval) -> Bool {
        guard revision == self.revision,frame.sequence > sequence,frontmost,
              currentWindow == frame.windowFrame,now.isFinite,frame.capturedAt.isFinite,
              frame.capturedAt <= now,now-frame.capturedAt <= 1 else { return false }
        sequence = frame.sequence; return true
    }
}

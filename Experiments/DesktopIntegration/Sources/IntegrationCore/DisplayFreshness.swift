import Foundation
public enum DisplayFreshness {
    /// No new content was observed in the quiet case; this does not prove a silent stream is healthy.
    /// Once newer pixels arrive, an older full-window image has a strict retention budget.
    public static func allows(_ frame:FrameBinding,latestReceivedSequence:UInt64,now:Double) -> Bool {
        guard now.isFinite,frame.capturedAt.isFinite,now >= frame.capturedAt,latestReceivedSequence >= frame.sequence else { return false }
        return latestReceivedSequence == frame.sequence || now-frame.capturedAt <= 0.25
    }
}

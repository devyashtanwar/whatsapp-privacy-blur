import Foundation
import CoreGraphics

/// Every complete external frame revokes reveal: no sharp pixels survive observed scroll.
/// External capture cannot observe movement before macOS delivers that frame.
public final class ExternalHover {
    public private(set) var revealedID: UInt64?
    private var lastPoint: CGPoint?
    private var lastTime: TimeInterval = 0
    private var frameTime: TimeInterval?
    private var sequence: UInt64 = 0
    private var leaseStart: TimeInterval?
    private var expiredID: UInt64?
    public private(set) var revision: UInt64 = 0
    public init() {}
    private var visible = true
    public func visibilityChanged(_ visible: Bool,now: TimeInterval) {
        guard advance(now) else { self.visible = false; return }
        guard visible != self.visible else { return }
        self.visible = visible; invalidate(); lastPoint = nil; expiredID = nil
        frameTime = visible ? now : nil
    }
    public func permitsCompletion(revision: UInt64,item: UInt64?,now: TimeInterval) -> Bool {
        guard revision == self.revision,item != nil,visible else { return false }
        return tick(now: now) == item
    }
    public func newFrame(sequence: UInt64, now: TimeInterval) {
        invalidate(); lastPoint = nil
        guard advance(now), sequence > self.sequence else { frameTime = nil; return }
        self.sequence = sequence; frameTime = now; expiredID = nil
    }
    public func invalidate() { revision &+= 1; revealedID = nil; leaseStart = nil }
    public func pointer(_ point: CGPoint, region: DetectedRegion?, settings: BlurSettings, now: TimeInterval) -> UInt64? {
        guard advance(now), point.x.isFinite, point.y.isFinite else { invalidate(); return nil }
        expire(now)
        let moved = lastPoint.map { $0 != point } ?? false; lastPoint = point
        guard visible, let frameTime = frameTime, now-frameTime >= 0.15,
              let region = region, region.bounds.contains(point), settings.permitsHover(region.category) else {
            if region == nil { expiredID = nil }; invalidate(); return nil
        }
        guard moved else { if revealedID != region.id { invalidate() }; return revealedID }
        if expiredID != region.id { expiredID = nil }
        guard expiredID != region.id else { invalidate(); return nil }
        if revealedID != region.id { revealedID = region.id; leaseStart = now }
        return revealedID
    }
    public func tick(now: TimeInterval) -> UInt64? {
        guard advance(now) else { return nil }; expire(now); return revealedID
    }
    private func advance(_ now: TimeInterval) -> Bool {
        guard now.isFinite, now >= lastTime else { invalidate(); frameTime = nil; return false }
        lastTime = now; return true
    }
    private func expire(_ now: TimeInterval) {
        if let leaseStart = leaseStart, now-leaseStart >= 2 { expiredID = revealedID; invalidate() }
    }
}

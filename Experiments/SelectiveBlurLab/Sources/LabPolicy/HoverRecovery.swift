import Foundation
import CoreGraphics

public enum ScrollSignal { case prepare, move, end }

/// One bounded motion timestamp per viewport. Notifications are observations,
/// not independent locks that require perfectly paired callbacks.
public final class HoverRecovery {
    public private(set) var revealedID: Int?
    private var permitted = false
    private var activity: [Int: TimeInterval] = [:]
    private var lastPoint: CGPoint?
    private var started: TimeInterval?
    private var expiredID: Int?
    private var lastTime: TimeInterval = 0
    public init() {}
    public func setPermitted(_ value: Bool) {
        if permitted != value { permitted = value; invalidate() }
    }
    public func invalidate() { revealedID = nil; started = nil }
    public func scroll(_ signal: ScrollSignal, in pane: Int, now: TimeInterval) {
        guard advance(now) else { return }
        switch signal {
        case .move: activity[pane] = now; invalidate()
        case .prepare:
            // Preparation without content movement is not a persistent scroll lock.
            invalidate()
        case .end: break // Duplicate/late end events do not revoke a new hover.
        }
    }
    public func pointer(item: Int?, position: CGPoint, now: TimeInterval) -> Int? {
        guard advance(now), position.x.isFinite, position.y.isFinite else { invalidate(); return nil }
        expire(now)
        let moved = lastPoint != position
        lastPoint = position
        guard permitted, activity.isEmpty else { invalidate(); return nil }
        guard moved else {
            if revealedID != item { invalidate() }
            return revealedID
        }
        guard let item = item else { expiredID = nil; invalidate(); return nil }
        if expiredID != item { expiredID = nil }
        guard expiredID != item else { invalidate(); return nil }
        if revealedID != item { revealedID = item; started = now }
        return revealedID
    }
    public func exit(now: TimeInterval) {
        guard advance(now) else { return }
        invalidate()
        if permitted { lastPoint = nil; expiredID = nil }
    }
    public func tick(now: TimeInterval) -> Int? {
        guard advance(now) else { return nil }
        expire(now)
        if !permitted || !activity.isEmpty { invalidate() }
        return revealedID // Eligibility may recover; timers never acquire a reveal.
    }
    public var waitingForScroll: Bool { !activity.isEmpty }
    private func advance(_ now: TimeInterval) -> Bool {
        guard now.isFinite, now >= lastTime else { invalidate(); return false }
        lastTime = now
        activity = activity.filter { now - $0.value < 0.15 }
        return true
    }
    private func expire(_ now: TimeInterval) {
        if let started = started, now - started >= 2 {
            expiredID = revealedID; invalidate()
        }
    }
}

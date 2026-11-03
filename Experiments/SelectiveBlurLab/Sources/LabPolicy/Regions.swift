import Foundation
import CoreGraphics
public struct Region: Equatable {
    public let id: Int
    public let frame: CGRect
    public init(_ id: Int, _ frame: CGRect) { self.id = id; self.frame = frame }
}
public enum Evidence { case instrumentedFixture, windowBoundsOnly }
public enum GeometryState: Equatable { case fixtureReady, unsupported, stale, invalid }
public struct GeometryPlan {
    public let state: GeometryState
    public let regions: [Region]
    public init(_ state: GeometryState, _ regions: [Region] = []) { self.state = state; self.regions = regions }
}
public enum RegionPlanner {
    public static func plan(_ regions: [Region], excluding: [CGRect], within viewport: CGRect, evidence: Evidence, observedAt: TimeInterval, now: TimeInterval) -> GeometryPlan {
        guard evidence == .instrumentedFixture else { return GeometryPlan(.unsupported) }
        guard observedAt.isFinite, now.isFinite, now >= observedAt, now - observedAt <= 0.25 else { return GeometryPlan(.stale) }
        guard !regions.isEmpty else { return GeometryPlan(.unsupported) }
        func valid(_ r: CGRect) -> Bool {
            r.origin.x.isFinite && r.origin.y.isFinite && r.width.isFinite && r.height.isFinite &&
            r.width > 0 && r.height > 0 && r.maxX.isFinite && r.maxY.isFinite
        }
        guard valid(viewport), excluding.allSatisfy(valid) else { return GeometryPlan(.invalid) }
        var ids = Set<Int>()
        for region in regions {
            guard valid(region.frame), viewport.contains(region.frame), ids.insert(region.id).inserted,
                  !excluding.contains(where: { $0.intersects(region.frame) }) else { return GeometryPlan(.invalid) }
        }
        return GeometryPlan(.fixtureReady, regions)
    }
}
public final class RevealLease {
    private var hovered: Int?
    private var entered: TimeInterval?
    private var layoutEpoch: Int?
    private var blocked = false
    private var requiresExit = false
    public init() {}
    public func update(item: Int?, active: Bool, epoch: Int, now: TimeInterval) -> Int? {
        guard now.isFinite, now >= 0 else { requiresExit = true; blocked = true; return nil }
        // Nil during suspension means sampling stopped, not physical pointer exit.
        guard active else { requiresExit = true; blocked = true; entered = nil; return nil }
        guard let item = item else {
            hovered = nil; entered = nil; layoutEpoch = epoch; blocked = false; requiresExit = false
            return nil
        }
        if let previous = layoutEpoch, previous != epoch {
            hovered = item; entered = nil; blocked = true; requiresExit = true
        }
        layoutEpoch = epoch
        guard !requiresExit else { hovered = item; return nil }
        if hovered != item { hovered = item; entered = now; blocked = false }
        guard !blocked, let entered = entered, now >= entered, now - entered < 2 else { blocked = true; return nil }
        return item
    }
}

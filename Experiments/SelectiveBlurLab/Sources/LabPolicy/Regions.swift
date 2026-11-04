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

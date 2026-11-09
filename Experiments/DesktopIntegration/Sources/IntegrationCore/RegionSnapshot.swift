import Foundation
import CoreGraphics

/// Coordinates are image pixels, not AppKit points. No content-bearing IDs.
public struct FrameBinding: Equatable {
    public var session: UInt64
    public var sequence: UInt64
    public var windowID: UInt32
    public var processID: Int32
    public var processGeneration: TimeInterval
    public var capturedAt: TimeInterval
    public var width: Int
    public var height: Int
    public var scale: Double
    public var windowFrame: CGRect
    public init(session: UInt64, sequence: UInt64, windowID: UInt32, processID: Int32,
                processGeneration: TimeInterval, capturedAt: TimeInterval, width: Int, height: Int, scale: Double, windowFrame: CGRect) {
        self.session = session; self.sequence = sequence; self.windowID = windowID; self.processID = processID
        self.processGeneration = processGeneration; self.capturedAt = capturedAt
        self.width = width; self.height = height; self.scale = scale; self.windowFrame = windowFrame
    }
}
public struct DetectedRegion {
    public let id: UInt64
    public let category: BlurCategory
    public let bounds: CGRect
    public init(id: UInt64, category: BlurCategory, bounds: CGRect) { self.id = id; self.category = category; self.bounds = bounds }
}
/// Only an implemented, separately accepted layout provider may supply supportedLayout.
/// Generic text boxes or instrumented lab geometry are not that evidence.
public enum RegionEvidence { case textGeometryOnly, syntheticFixture, supportedLayout }
public struct RegionSnapshot {
    public var frame: FrameBinding
    public var evidence: RegionEvidence
    public var supportedCategories: [BlurCategory]
    public var regions: [DetectedRegion]
    public var controls: [CGRect]
    public init(frame: FrameBinding, evidence: RegionEvidence, supportedCategories: [BlurCategory], regions: [DetectedRegion], controls: [CGRect]) {
        self.frame = frame; self.evidence = evidence; self.supportedCategories = supportedCategories; self.regions = regions; self.controls = controls
    }
}
public enum RegionValidationState { case ready, disabled, unsupported, stale, mismatch, invalid }
public struct RegionPlan {
    public let state: RegionValidationState
    public let regions: [DetectedRegion]
    public init(_ state: RegionValidationState, regions: [DetectedRegion] = []) { self.state = state; self.regions = regions }
}
/// The expected binding must come from the current capture event, not the candidate snapshot.
/// Semantic completeness is the layout provider's separate obligation.
public enum RegionValidator {
    public static func validate(_ snapshot: RegionSnapshot, expected: FrameBinding, settings: BlurSettings,
                                now: TimeInterval, maxAge: TimeInterval) -> RegionPlan {
        guard settings.needsCapture else { return RegionPlan(.disabled) }
        func validFrame(_ f: FrameBinding) -> Bool {
            let r = f.windowFrame
            return f.session > 0 && f.sequence > 0 && f.windowID > 0 && f.processID > 0 &&
                f.processGeneration.isFinite && f.processGeneration > 0 &&
                f.capturedAt.isFinite && f.capturedAt >= 0 && f.width > 0 && f.width <= 4096 &&
                f.height > 0 && f.height <= 4096 && f.scale.isFinite && f.scale > 0 &&
                r.origin.x.isFinite && r.origin.y.isFinite && r.size.width.isFinite && r.size.height.isFinite &&
                r.size.width > 0 && r.size.height > 0 && r.maxX.isFinite && r.maxY.isFinite
        }
        guard validFrame(expected), validFrame(snapshot.frame), now.isFinite, maxAge.isFinite, maxAge > 0 else { return RegionPlan(.invalid) }
        guard snapshot.frame == expected else { return RegionPlan(.mismatch) }
        guard expected.capturedAt <= now, now - expected.capturedAt <= maxAge else { return RegionPlan(.stale) }
        guard snapshot.evidence == .supportedLayout,
              BlurCategory.allCases.filter({ settings.isEnabled($0) }).allSatisfy({ snapshot.supportedCategories.contains($0) }) else {
            return RegionPlan(.unsupported)
        }
        let viewport = CGRect(x: 0, y: 0, width: expected.width, height: expected.height)
        func validRect(_ r: CGRect) -> Bool {
            r.origin.x.isFinite && r.origin.y.isFinite && r.size.width.isFinite && r.size.height.isFinite &&
                r.size.width > 0 && r.size.height > 0 && r.maxX.isFinite && r.maxY.isFinite && viewport.contains(r)
        }
        guard snapshot.controls.allSatisfy(validRect) else { return RegionPlan(.invalid) }
        var ids = Set<UInt64>()
        for region in snapshot.regions {
            guard validRect(region.bounds), ids.insert(region.id).inserted else { return RegionPlan(.invalid) }
        }
        let enabled = snapshot.regions.filter { settings.isEnabled($0.category) }
        let excluded = snapshot.controls + snapshot.regions.filter { !settings.isEnabled($0.category) }.map(\.bounds)
        guard enabled.allSatisfy({ region in !excluded.contains { $0.intersects(region.bounds) } }) else { return RegionPlan(.invalid) }
        return RegionPlan(.ready, regions: enabled)
    }
}

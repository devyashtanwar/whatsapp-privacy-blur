import Foundation
import CoreGraphics
public struct CaptureTarget: Hashable {
    public let windowID:UInt32
    public let pid:Int32
    public let generation:Double
    public init(windowID:UInt32,pid:Int32,generation:Double) { self.windowID = windowID;self.pid = pid;self.generation = generation }
}
public struct WindowCandidate: Equatable {
    public let target:CaptureTarget
    public let frame:CGRect
    public let width:Int
    public let height:Int
    public init(target:CaptureTarget,frame:CGRect,width:Int,height:Int) { self.target = target;self.frame = frame;self.width = width;self.height = height }
}
public struct AttachmentChanges { public var start:[WindowCandidate] = [];public var stop:[CaptureTarget] = [];public var partial = false }
/// Bounded intent/target reconciliation. Targets here are already publisher-authenticated.
public final class AutomaticAttachment {
    private var active:[CaptureTarget:WindowCandidate] = [:]
    private var failures:[CaptureTarget:(count:Int,after:Double)] = [:]
    public init() {}
    public func reconcile(enabled:Bool,permission:Bool,awake:Bool,targets:[WindowCandidate],now:Double) -> AttachmentChanges {
        var changes = AttachmentChanges()
        guard enabled,permission,awake,now.isFinite else {
            changes.stop = Array(active.keys);active.removeAll();return changes
        }
        let available = targets.filter { c in
            c.target.pid > 0 && c.target.windowID > 0 && c.target.generation.isFinite && c.target.generation > 0 &&
            c.width > 0 && c.height > 0 && c.width <= 4096 && c.height <= 4096 &&
            c.frame.minX.isFinite && c.frame.minY.isFinite && c.frame.width.isFinite && c.frame.height.isFinite && c.frame.width > 0 && c.frame.height > 0
        }
        let availableIDs = Set(available.map(\.target))
        // Remove old process/window failures, keeping memory bounded across restarts.
        failures = failures.filter { availableIDs.contains($0.key) }
        var desired:[CaptureTarget:WindowCandidate] = [:]
        var pixels = 0
        for c in available.sorted(by:{$0.target.windowID < $1.target.windowID}) {
            guard desired[c.target] == nil else { continue }
            let cost = c.width*c.height
            guard desired.count < 2,pixels+cost <= 256*1024*1024/24 else { changes.partial = true;continue }
            if let failed = failures[c.target],failed.count > 3 || now < failed.after { changes.partial = true;continue }
            pixels += cost;desired[c.target] = c
        }
        if available.count != targets.count { changes.partial = true }
        for (key,value) in active where desired[key] != value { changes.stop.append(key) }
        for (key,value) in desired where active[key] != value { changes.start.append(value) }
        active = desired;return changes
    }
    public func failed(_ target:CaptureTarget,permanent:Bool,now:Double) {
        active.removeValue(forKey:target)
        let count = (failures[target]?.count ?? 0)+1
        let delays = [0.25,0.5,1.0]
        failures[target] = (permanent ? 4 : count,now+(count <= 3 ? delays[count-1] : 0))
    }
    public func retiredForGeometry(_ target:CaptureTarget) { active.removeValue(forKey:target) }
    public func resetFailures() { failures.removeAll() }
}

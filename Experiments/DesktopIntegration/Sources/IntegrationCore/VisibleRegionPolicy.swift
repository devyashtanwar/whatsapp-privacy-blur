import CoreGraphics
public enum VisibleRegionPolicy {
    /// Conservative rectangles for hover, or callers with known opaque geometry.
    /// Window bounds alone do not prove opacity; native Z-order governs base rendering.
    public static func exposed(target:CGRect,occluders:[CGRect]) -> [CGRect] {
        func valid(_ r:CGRect)->Bool { r.minX.isFinite && r.minY.isFinite && r.width.isFinite && r.height.isFinite && r.width > 0 && r.height > 0 }
        guard valid(target),occluders.allSatisfy(valid) else { return [] }
        var pieces = [target]
        for cover in occluders {
            var next: [CGRect] = []
            for r in pieces {
                let i = r.intersection(cover)
                if i.isNull || i.isEmpty { next.append(r);continue }
                for part in [CGRect(x:r.minX,y:r.minY,width:r.width,height:i.minY-r.minY),
                             CGRect(x:r.minX,y:i.maxY,width:r.width,height:r.maxY-i.maxY),
                             CGRect(x:r.minX,y:i.minY,width:i.minX-r.minX,height:i.height),
                             CGRect(x:i.maxX,y:i.minY,width:r.maxX-i.maxX,height:i.height)] where part.width > 0 && part.height > 0 { next.append(part) }
            }
            guard next.count <= 128 else { return [] };pieces = next
        };return pieces
    }
}
public enum NativeWindowOrderPolicy {
    /// Front-to-back IDs above the target must end in exactly our normal-level overlay.
    public static func canShow(overlay:Int,aboveTarget:[Int]) -> Bool {
        overlay > 0 && aboveTarget.last == overlay && aboveTarget.filter { $0 == overlay }.count == 1
    }
}

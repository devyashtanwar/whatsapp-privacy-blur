import CoreGraphics
import Foundation
import Vision
import IntegrationCore

/// Candidate geometry only. This is deliberately not supported-layout evidence.
public struct ExperimentalRegions { public let regions: [DetectedRegion]; public let conversationAvailable: Bool }
public enum NativeLayoutDetector {
    public static func detect(_ image: CGImage) throws -> ExperimentalRegions? {
        let analysis = try UIAnchorRecognition.analyze(image)
        let edges = persistentDividers(in: image)
        let search = analysis.anchors.filter { $0.kind == .search }.max { $0.bounds.midY < $1.bounds.midY }
        let archived = analysis.anchors.filter { $0.kind == .archived }.max { $0.bounds.midY < $1.bounds.midY }
        let composer = analysis.anchors.first { $0.kind == .composer }
        let right: CGFloat?,left: CGFloat?
        if let search = search {
            let end = min(composer?.bounds.minX ?? CGFloat(image.width)*0.7,CGFloat(image.width)*0.7)
            let candidates = edges.filter { $0 > search.bounds.maxX+4 && $0 < end-4 }
            right = candidates.count == 1 ? candidates.first : nil; left = nil
        } else if let archived = archived {
            left = edges.last { $0 < archived.bounds.minX-4 }
            right = edges.first { $0 > archived.bounds.maxX+4 && $0 < CGFloat(image.width)*0.7 }
        } else { return nil }
        var rectangles: [CGRect] = []
        if composer != nil {
            let request = VNDetectRectanglesRequest()
            request.maximumObservations = 64; request.minimumConfidence = 0.65
            request.minimumSize = 0.02; request.minimumAspectRatio = 0.08
            try VNImageRequestHandler(cgImage: image,options: [:]).perform([request])
            rectangles = (request.results ?? []).map { b in
                let r = b.boundingBox
                return CGRect(x: r.minX*CGFloat(image.width),y: r.minY*CGFloat(image.height),width: r.width*CGFloat(image.width),height: r.height*CGFloat(image.height))
            }
        }
        return plan(width: image.width,height: image.height,divider: right,anchors: analysis.anchors,text: analysis.text,rectangles: rectangles,sidebarLeft: left)
    }
    public static func plan(width: Int,height: Int,divider: CGFloat?,anchors: [UIAnchor],text: [CGRect],rectangles: [CGRect],sidebarLeft: CGFloat? = nil) -> ExperimentalRegions? {
        let w = CGFloat(width), h = CGFloat(height)
        guard width >= 600,height >= 400,width <= 4096,height <= 4096,
              let divider = divider,divider.isFinite,divider > w*0.18,divider < w*0.7 else { return nil }
        let pad = max(3,h/350)
        let search = anchors.filter { $0.kind == .search && $0.bounds.maxX < divider }.max { $0.bounds.midY < $1.bounds.midY }
        let archived = anchors.filter { $0.kind == .archived && $0.bounds.maxX < divider }.max { $0.bounds.midY < $1.bounds.midY }
        let anchor: UIAnchor, rowStart: CGFloat
        if let search = search { anchor = search; rowStart = search.bounds.minX-pad*4 }
        else if let archived = archived,let left = sidebarLeft,left.isFinite,left >= 0,left < archived.bounds.minX {
            anchor = archived; rowStart = left+pad*10
        } else { return nil }
        guard anchor.bounds.minY > h*0.65 else { return nil }
        let viewport = CGRect(x: 0,y: 0,width: w,height: h)
        let top = min(h-pad,anchor.bounds.minY-pad*3)
        let composer = anchors.filter { $0.kind == .composer && $0.bounds.minX > divider && $0.bounds.maxY < h*0.2 }.min { $0.bounds.midY < $1.bounds.midY }
        let bottom = composer.map { $0.bounds.maxY+pad*4 }
        let body: CGRect? = bottom.flatMap { bottom in
            guard top > bottom+h*0.4 else { return nil }
            return CGRect(x: divider+pad,y: bottom,width: w-divider-pad*2,height: top-bottom)
        }
        var output: [DetectedRegion] = []
        func add(_ category: BlurCategory,_ bounds: CGRect) {
            let b = bounds.integral.intersection(viewport)
            guard !b.isNull,b.width > 0,b.height > 0,b.minX.isFinite,b.minY.isFinite else { return }
            output.append(DetectedRegion(id: UInt64(output.count+1),category: category,bounds: b))
        }
        // Infer name/preview pairs from actual OCR baselines, never a fixed row grid.
        let rows = text.filter { $0.minX >= rowStart && $0.maxX < divider-pad && $0.maxY < top && $0.minY > pad }
            .sorted { $0.midY > $1.midY }
        var used = Set<Int>()
        for (i,name) in rows.enumerated() where !used.contains(i) {
            guard let j = rows.indices.first(where: { j in
                j > i && !used.contains(j) && abs(rows[j].minX-name.minX) <= max(pad*4,name.height) &&
                    name.minY > rows[j].midY && name.minY-rows[j].maxY < name.height*2.5
            }) else { continue }
            let preview = rows[j]; used.insert(i); used.insert(j)
            add(.contactName,name.insetBy(dx: -pad,dy: -pad))
            add(.sidebarPreview,preview.insetBy(dx: -pad,dy: -pad))
            let avatar = max(name.height*2.3,pad*10)
            add(.avatar,CGRect(x: name.minX-avatar-pad*3,y: (name.midY+preview.midY-avatar)/2,width: avatar,height: avatar))
        }
        if let body = body {
        // Header identity is separate from the conversation body and composer.
        for name in text where name.minX > divider+pad*12 && name.maxX < divider+(w-divider)*0.65 && name.minY > top+pad && name.maxY < h-pad {
            add(.contactName,name.insetBy(dx: -pad,dy: -pad))
            let size = max(name.height*2.2,pad*10)
            add(.avatar,CGRect(x: name.minX-size-pad*3,y: name.midY-size/2,width: size,height: size))
        }
        // Rectangle observations can include image-only messages; completeness is unproven.
        var messageBoxes = rectangles.filter { body.contains($0) && $0.width > pad*10 && $0.height > pad*6 && $0.width*$0.height < body.width*body.height*0.8 }
        for box in text where body.contains(box) {
            if !messageBoxes.contains(where: { $0.contains(box) }) { messageBoxes.append(box.insetBy(dx: -pad,dy: -pad).intersection(body)) }
        }
        // Merge overlapping pieces before hover so an item never exposes only half its own mask.
        var merged: [CGRect] = []
        for var box in messageBoxes {
            var i = 0
            while i < merged.count {
                if merged[i].insetBy(dx: -pad,dy: -pad).intersects(box) {
                    box = box.union(merged.remove(at: i)); i = 0
                } else { i += 1 }
            }; merged.append(box)
        }
        for box in merged { add(.conversationMessage,box.intersection(body)) }
        }
        guard !output.isEmpty else { return nil }
        return ExperimentalRegions(regions: output,conversationAvailable: body != nil)
    }
    /// Group persistent pixel edges; no fixed pane coordinates or invented row grid.
    private static func persistentDividers(in image: CGImage) -> [CGFloat] {
        let w = image.width,h = image.height
        guard w >= 600,h >= 400,w <= 4096,h <= 4096 else { return [] }
        var bytes = [UInt8](repeating: 0,count: w*h*4)
        let rendered = bytes.withUnsafeMutableBytes { b -> Bool in
            guard let c = CGContext(data: b.baseAddress,width: w,height: h,bitsPerComponent: 8,bytesPerRow: w*4,space: CGColorSpaceCreateDeviceRGB(),bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
            c.draw(image,in: CGRect(x: 0,y: 0,width: w,height: h)); return true
        }
        guard rendered else { return [] }
        var groups: [[Int]] = []
        for x in stride(from: max(4,w/20),to: w*4/5,by: 2) {
            var strong = 0,total = 0
            for y in stride(from: h/5,to: h*4/5,by: max(1,h/100)) {
                let a = (y*w+x-2)*4,b = (y*w+x+2)*4
                let delta = (0..<3).reduce(0) { $0+abs(Int(bytes[a+$1])-Int(bytes[b+$1])) }
                total += 1; if delta > 12 { strong += 1 }
            }
            if total > 0 && Double(strong)/Double(total) > 0.85 {
                if let last = groups.last?.last,x-last <= max(6,w/500) { groups[groups.count-1].append(x) }
                else { groups.append([x]) }
            }
        }
        return groups.map { CGFloat($0[$0.count/2]) }
    }
}

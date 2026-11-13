import CoreGraphics
import Foundation
import Vision
import IntegrationCore

/// Candidate geometry only. This is deliberately not supported-layout evidence.
public struct ExperimentalRegions { public let regions: [DetectedRegion] }
public enum NativeLayoutDetector {
    public static func detect(_ image: CGImage) throws -> ExperimentalRegions? {
        let analysis = try UIAnchorRecognition.analyze(image)
        let divider = divider(in: image,anchors: analysis.anchors)
        let request = VNDetectRectanglesRequest()
        request.maximumObservations = 64; request.minimumConfidence = 0.65
        request.minimumSize = 0.02; request.minimumAspectRatio = 0.08
        try VNImageRequestHandler(cgImage: image,options: [:]).perform([request])
        let rectangles = (request.results ?? []).map { b -> CGRect in
            let r = b.boundingBox
            return CGRect(x: r.minX * CGFloat(image.width),y: r.minY * CGFloat(image.height),width: r.width * CGFloat(image.width),height: r.height * CGFloat(image.height))
        }
        return plan(width: image.width,height: image.height,divider: divider,anchors: analysis.anchors,text: analysis.text,rectangles: rectangles)
    }
    public static func plan(width: Int,height: Int,divider: CGFloat?,anchors: [UIAnchor],text: [CGRect],rectangles: [CGRect]) -> ExperimentalRegions? {
        let w = CGFloat(width), h = CGFloat(height)
        guard width >= 600, height >= 400,width <= 4096,height <= 4096,
              let divider = divider, divider.isFinite, divider > w*0.18,divider < w*0.7,
              let search = anchors.filter({ $0.kind == .search && $0.bounds.maxX < divider }).max(by: { $0.bounds.midY < $1.bounds.midY }),
              let composer = anchors.filter({ $0.kind == .composer && $0.bounds.minX > divider }).min(by: { $0.bounds.midY < $1.bounds.midY }),
              search.bounds.minY > h*0.65,composer.bounds.maxY < h*0.2 else { return nil }
        let viewport = CGRect(x: 0,y: 0,width: w,height: h)
        let pad = max(3,h/350)
        let top = min(h-pad,search.bounds.minY-pad*3)
        let bottom = composer.bounds.maxY + pad*4
        guard top > bottom+h*0.4 else { return nil }
        let body = CGRect(x: divider+pad,y: bottom,width: w-divider-pad*2,height: top-bottom)
        var output: [DetectedRegion] = []
        func add(_ category: BlurCategory,_ bounds: CGRect) {
            let b = bounds.integral.intersection(viewport)
            guard !b.isNull,b.width > 0,b.height > 0,b.minX.isFinite,b.minY.isFinite else { return }
            output.append(DetectedRegion(id: UInt64(output.count+1),category: category,bounds: b))
        }
        // Infer name/preview pairs from actual OCR baselines, never a fixed row grid.
        let rows = text.filter { $0.minX >= search.bounds.minX-pad*4 && $0.maxX < divider-pad && $0.maxY < top && $0.minY > pad }
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
        guard !output.isEmpty else { return nil }
        return ExperimentalRegions(regions: output)
    }
    private static func divider(in image: CGImage,anchors: [UIAnchor]) -> CGFloat? {
        guard let composer = anchors.first(where: { $0.kind == .composer }),
              let search = anchors.first(where: { $0.kind == .search }) else { return nil }
        let w = image.width,h = image.height
        var bytes = [UInt8](repeating: 0,count: w*h*4)
        let rendered = bytes.withUnsafeMutableBytes { b -> Bool in
            guard let c = CGContext(data: b.baseAddress,width: w,height: h,bitsPerComponent: 8,bytesPerRow: w*4,space: CGColorSpaceCreateDeviceRGB(),bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
            c.draw(image,in: CGRect(x: 0,y: 0,width: w,height: h)); return true
        }
        guard rendered else { return nil }
        let start = max(Int(search.bounds.maxX)+4,Int(Double(w)*0.18))
        let end = min(Int(composer.bounds.minX)-4,Int(Double(w)*0.7))
        guard end > start else { return nil }
        var candidates: [Int] = []
        for x in stride(from: start,to: end,by: 2) {
            var strong = 0,total = 0
            for y in stride(from: h/5,to: h*4/5,by: max(1,h/100)) {
                let a = (y*w+x-2)*4,b = (y*w+x+2)*4
                let delta = (0..<3).reduce(0) { $0 + abs(Int(bytes[a+$1])-Int(bytes[b+$1])) }
                total += 1; if delta > 12 { strong += 1 }
            }
            if total > 0 && Double(strong)/Double(total) > 0.85 { candidates.append(x) }
        }
        // Multiple separated persistent dividers are ambiguous; do not guess a pane boundary.
        guard let first = candidates.first, let last = candidates.last,last-first <= max(12,w/100) else { return nil }
        return CGFloat((first+last)/2)
    }
}

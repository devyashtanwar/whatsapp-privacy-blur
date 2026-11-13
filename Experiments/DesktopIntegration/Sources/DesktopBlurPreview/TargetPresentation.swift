import AppKit
import IntegrationCore

/// Public normal-level relative ordering only; never a globally floating privacy image.
/// Caller must revalidate target identity/session/geometry immediately before install.
final class TargetPresentation {
    private var window: NSWindow?
    private var view: NSImageView?
    var isVisible: Bool { window?.isVisible == true && window?.alphaValue == 1 }
    func install(_ image:CGImage,binding:FrameBinding,primaryMaxY:CGFloat) -> Bool {
        guard primaryMaxY.isFinite else { withdraw();return false }
        if window == nil {
            let w = NSWindow(contentRect:.zero,styleMask:.borderless,backing:.buffered,defer:false)
            w.isReleasedWhenClosed = false;w.ignoresMouseEvents = true;w.level = .normal
            w.hidesOnDeactivate = false;w.backgroundColor = .clear;w.isOpaque = false;w.hasShadow = false
            w.collectionBehavior = [.transient,.ignoresCycle];w.alphaValue = 0
            let v = NSImageView();v.imageScaling = .scaleAxesIndependently
            v.wantsLayer = true;v.layer?.cornerRadius = 10;v.layer?.masksToBounds = true
            w.contentView = v;window = w;view = v
        }
        let r = binding.windowFrame
        let rect = CGRect(x:r.minX,y:primaryMaxY-r.maxY,width:r.width,height:r.height)
        let existingOrder = window.map { w in
            isVisible && idsAbove(binding.windowID).map { NativeWindowOrderPolicy.canShow(overlay:w.windowNumber,aboveTarget:$0) } == true
        } ?? false
        if !existingOrder { window?.alphaValue = 0 }
        view?.image = NSImage(cgImage:image,size:rect.size);window?.setFrame(rect,display:false)
        guard existingOrder || restoreOrder(target:binding.windowID) else { withdraw();return false }
        window?.alphaValue = 1;return isVisible
    }
    func maintainOrder(target:UInt32) -> Bool {
        guard let w = window,isVisible else { return false }
        if let ids = idsAbove(target),NativeWindowOrderPolicy.canShow(overlay:w.windowNumber,aboveTarget:ids) { return true }
        w.alphaValue = 0
        guard restoreOrder(target:target) else { withdraw();return false }
        w.alphaValue = 1;return true
    }
    func hoverRegions(binding:FrameBinding) -> [CGRect] {
        guard let rows = CGWindowListCopyWindowInfo([.optionOnScreenAboveWindow,.excludeDesktopElements],binding.windowID) as? [[String:Any]] else { return [] }
        var covers: [CGRect] = []
        for row in rows {
            if (row[kCGWindowNumber as String] as? NSNumber)?.intValue == window?.windowNumber { continue }
            guard let alpha = row[kCGWindowAlpha as String] as? NSNumber,alpha.doubleValue > 0 else { continue }
            guard let b = row[kCGWindowBounds as String] as? [String:Any],let rect = CGRect(dictionaryRepresentation:b as CFDictionary) else { return [] }
            covers.append(rect)
        }
        return VisibleRegionPolicy.exposed(target:binding.windowFrame,occluders:covers)
    }
    private func restoreOrder(target:UInt32) -> Bool {
        guard let w = window else { return false }
        w.order(.above,relativeTo:Int(target))
        guard let ids = idsAbove(target) else { return false }
        return NativeWindowOrderPolicy.canShow(overlay:w.windowNumber,aboveTarget:ids)
    }
    private func idsAbove(_ target:UInt32) -> [Int]? {
        guard let rows = CGWindowListCopyWindowInfo([.optionOnScreenAboveWindow,.excludeDesktopElements],target) as? [[String:Any]] else { return nil }
        var ids: [Int] = []
        for row in rows { guard let id = row[kCGWindowNumber as String] as? NSNumber else { return nil };ids.append(id.intValue) }
        return ids
    }
    func withdraw() { window?.orderOut(nil);view?.image = nil }
}

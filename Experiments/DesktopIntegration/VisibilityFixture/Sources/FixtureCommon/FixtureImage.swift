import AppKit
import IntegrationCore
import NativeRendering
public enum FixtureImage {
    public static func make(id:Int,blurred:Bool) -> CGImage {
        let image = NSImage(size:NSSize(width:900,height:700),flipped:false) { rect in
            NSColor(calibratedWhite:0.10,alpha:1).setFill();rect.fill()
            NSColor(calibratedWhite:0.18,alpha:1).setFill();NSRect(x:180,y:0,width:270,height:700).fill()
            let font:[NSAttributedString.Key:Any] = [.font:NSFont.systemFont(ofSize:22),.foregroundColor:NSColor.white]
            ("Visibility fixture · window \(id)" as NSString).draw(at:NSPoint(x:30,y:640),withAttributes:font)
            ("Invented Contact" as NSString).draw(at:NSPoint(x:240,y:550),withAttributes:font)
            ("Synthetic preview" as NSString).draw(at:NSPoint(x:240,y:510),withAttributes:font)
            ("Drag this window. Put another app over part of it." as NSString).draw(at:NSPoint(x:35,y:70),withAttributes:font)
            ("Only the invented preview should remain blurred." as NSString).draw(at:NSPoint(x:35,y:35),withAttributes:font)
            return true
        }.cgImage(forProposedRect:nil,context:nil,hints:nil)!
        guard blurred else { return image }
        let scale = CGFloat(image.width)/900
        let r = CGRect(x:235,y:500,width:210,height:45).applying(CGAffineTransform(scaleX:scale,y:scale))
        return FrameCompositor.render(image,plan:RegionPlan(.ready,regions:[DetectedRegion(id:1,category:.sidebarPreview,bounds:r)]),settings:BlurSettings(sidebarPreviews:true,conversationMessages:false))!
    }
}

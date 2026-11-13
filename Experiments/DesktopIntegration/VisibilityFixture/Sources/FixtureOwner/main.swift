import AppKit
import FixtureCommon
final class SourceWindow:NSWindow {
    override var canBecomeKey:Bool { true }
    override var canBecomeMain:Bool { true }
}
final class Owner:NSObject,NSApplicationDelegate {
    var window:NSWindow!
    func applicationDidFinishLaunching(_ notification:Notification) {
        window = SourceWindow(contentRect:CGRect(x:0,y:0,width:900,height:700),styleMask:.borderless,backing:.buffered,defer:false)
        window.isReleasedWhenClosed = false;window.isMovableByWindowBackground = true
        let v = NSImageView();v.imageScaling = .scaleAxesIndependently
        window.contentView = v
        v.image = NSImage(cgImage:FixtureImage.make(id:window.windowNumber,blurred:false),size:window.frame.size)
        let menu = NSMenu();let root = NSMenuItem();menu.addItem(root)
        let appMenu = NSMenu();appMenu.addItem(withTitle:"Quit fixture",action:#selector(NSApplication.terminate(_:)),keyEquivalent:"q");root.submenu = appMenu;NSApp.mainMenu = menu
        window.center();window.makeKeyAndOrderFront(nil);NSApp.activate(ignoringOtherApps:true)
    }
}
let app = NSApplication.shared
app.setActivationPolicy(.regular)
let delegate = Owner();app.delegate = delegate
app.run()

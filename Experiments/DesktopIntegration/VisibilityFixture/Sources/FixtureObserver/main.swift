import AppKit
import FixtureCommon
import IntegrationCore
final class Observer:NSObject,NSApplicationDelegate,NSWindowDelegate {
    let presentation = TargetPresentation()
    let field = NSTextField(string:"")
    let status = NSTextField(wrappingLabelWithString:"Enter the window number shown by the invented fixture.")
    var target:UInt32?
    var timer:Timer?
    var window:NSWindow!
    var pixels:CGImage?
    func applicationDidFinishLaunching(_ notification:Notification) {
        window = NSWindow(contentRect:CGRect(x:0,y:0,width:450,height:190),styleMask:[.titled,.closable],backing:.buffered,defer:false)
        window.title = "Visibility fixture observer";window.isReleasedWhenClosed = false;window.delegate = self
        field.widthAnchor.constraint(equalToConstant:380).isActive = true;status.preferredMaxLayoutWidth = 380
        let menu = NSMenu();let root = NSMenuItem();menu.addItem(root)
        let appMenu = NSMenu();appMenu.addItem(withTitle:"Quit fixture",action:#selector(NSApplication.terminate(_:)),keyEquivalent:"q");root.submenu = appMenu;NSApp.mainMenu = menu
        let stack = NSStackView(views:[field,NSButton(title:"Attach to invented fixture",target:self,action:#selector(attach)),status])
        stack.orientation = .vertical;stack.spacing = 12;stack.edgeInsets = NSEdgeInsets(top:20,left:20,bottom:20,right:20)
        window.contentView = stack
        window.center();window.makeKeyAndOrderFront(nil);NSApp.activate(ignoringOtherApps:true)
        timer = Timer.scheduledTimer(withTimeInterval:0.1,repeats:true) { [weak self] _ in self?.tick() }
    }
    func windowWillClose(_ notification:Notification) { presentation.withdraw();NSApp.terminate(nil) }
    @objc func attach() { target = UInt32(field.stringValue);pixels = target.map { FixtureImage.make(id:Int($0),blurred:true) };tick() }
    func tick() {
        guard let target = target,let pixels = pixels,
              let rows = CGWindowListCopyWindowInfo(.optionIncludingWindow,target) as? [[String:Any]],let row = rows.first,
              let pid = row[kCGWindowOwnerPID as String] as? NSNumber,
              NSRunningApplication(processIdentifier:pid.int32Value)?.bundleIdentifier == "devyashtanwar.visibility-fixture-owner",
              let b = row[kCGWindowBounds as String] as? [String:Any],let rect = CGRect(dictionaryRepresentation:b as CFDictionary),
              let screen = NSScreen.screens.first else { presentation.withdraw();status.stringValue = "Invented fixture not found. No attachment.";return }
        let binding = FrameBinding(session:1,sequence:1,windowID:target,processID:pid.int32Value,processGeneration:1,capturedAt:ProcessInfo.processInfo.systemUptime,width:pixels.width,height:pixels.height,scale:Double(pixels.width)/Double(rect.width),windowFrame:rect)
        let shown = presentation.install(pixels,binding:binding,primaryMaxY:screen.frame.maxY)
        status.stringValue = shown ? "Relative ordering confirmed. Check visible invented blur beneath other windows." : "Native ordering unconfirmed. No fixture overlay displayed."
    }
}
let app = NSApplication.shared
app.setActivationPolicy(.regular)
let delegate = Observer();app.delegate = delegate
app.run()

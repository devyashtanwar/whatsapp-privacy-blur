import AppKit
import ScreenCaptureKit
import IntegrationCore

/// Catalog handles stay transient. No titles, display capture or unrelated pixels are read.
public final class DiscoveredWhatsAppWindow {
    public let candidate:WindowCandidate
    fileprivate let window:SCWindow
    fileprivate let process:NSRunningApplication
    fileprivate init(window:SCWindow,process:NSRunningApplication,width:Int,height:Int) {
        self.window = window;self.process = process
        candidate = WindowCandidate(target:CaptureTarget(windowID:window.windowID,pid:process.processIdentifier,generation:process.launchDate!.timeIntervalSince1970),frame:window.frame,width:width,height:height)
    }
}
public enum DiscoveryResult { case absent,untrusted,permissionRequired,failed,windows([DiscoveredWhatsAppWindow],unsupported:Bool) }
public final class WhatsAppDiscovery {
    private var busy = false
    private let worker = DispatchQueue(label:"local.whatsapp.authenticate",qos:.userInitiated)
    public init() {}
    public func scan(completion:@escaping(DiscoveryResult)->Void) -> Bool {
        precondition(Thread.isMainThread)
        guard !busy else { return false }
        guard ScreenPermission.preflight() else { completion(.permissionRequired);return true }
        let apps = NSWorkspace.shared.runningApplications.filter { $0.bundleIdentifier == "net.whatsapp.WhatsApp" && !$0.isTerminated }
        guard !apps.isEmpty else { completion(.absent);return true }
        busy = true
        worker.async {
            let identity = ProcessIdentityProvider()
            let allowed = identity.trustedPIDs(apps)
            let trusted = apps.filter { allowed.contains($0.processIdentifier) && ProcessIdentityProvider.stillCurrent($0) && $0.launchDate != nil }
            guard !trusted.isEmpty else { DispatchQueue.main.async { self.busy = false;completion(.untrusted) };return }
            SCShareableContent.getExcludingDesktopWindows(true,onScreenWindowsOnly:true) { content,error in
                DispatchQueue.main.async {
                    self.busy = false
                    guard ScreenPermission.preflight() else { completion(.permissionRequired);return }
                    guard error == nil,let content = content else { completion(.failed);return }
                    var windows:[DiscoveredWhatsAppWindow] = [];var unsupported = false
                    for window in content.windows {
                        guard window.isOnScreen,window.windowLayer == 0,let owner = window.owningApplication,
                              owner.bundleIdentifier == "net.whatsapp.WhatsApp",
                              let process = trusted.first(where:{$0.processIdentifier == owner.processID}),ProcessIdentityProvider.stillCurrent(process) else { continue }
                        // Catalog supplies metadata only; exact scope is checked again before starting a stream.
                        let scale = NSScreen.screens.map(\.backingScaleFactor).max() ?? 2
                        let width = ceil(window.frame.width*scale),height = ceil(window.frame.height*scale)
                        guard width.isFinite,height.isFinite,width > 0,height > 0,width <= 4096,height <= 4096 else { unsupported = true;continue }
                        windows.append(DiscoveredWhatsAppWindow(window:window,process:process,width:Int(width),height:Int(height)))
                    }
                    completion(.windows(windows,unsupported:unsupported))
                }
            }
        }
        return true
    }
}
// Only this module can inspect retained native handles, and no IDs are stored to disk.
extension DiscoveredWhatsAppWindow {
    var nativeWindow:SCWindow { window }
    var stillCurrent:Bool { ProcessIdentityProvider.stillCurrent(process) }
}

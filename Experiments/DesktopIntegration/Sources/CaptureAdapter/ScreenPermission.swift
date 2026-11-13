import Foundation

import CoreGraphics
import IntegrationCore
/// Never requests permission during launch, retries or discovery.
public enum ScreenPermission {
    public static func preflight() -> Bool { CGPreflightScreenCaptureAccess() }
    /// Called only from the explicit Enable button, at most once per process.
    private static var gate = PermissionRequestGate()
    public static func requestFromUserAction() -> Bool {
        precondition(Thread.isMainThread)
        if preflight() { return true }
        guard gate.shouldRequest(alreadyGranted:false,userAction:true) else { return false }
        return CGRequestScreenCaptureAccess()
    }
}

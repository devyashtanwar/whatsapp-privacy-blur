/// Permission is never prompted by startup or recovery, and a denial cannot make a prompt loop.
public struct PermissionRequestGate {
    private var requested = false
    public init() {}
    public mutating func shouldRequest(alreadyGranted:Bool,userAction:Bool) -> Bool {
        guard !alreadyGranted,userAction,!requested else { return false }
        requested = true;return true
    }
}

public struct RuntimeAvailability {
    private var sessionActive:Bool
    private var screenAwake:Bool
    public init(sessionActive:Bool,screenAwake:Bool) { self.sessionActive = sessionActive;self.screenAwake = screenAwake }
    public var canCapture:Bool { sessionActive && screenAwake }
    public mutating func sessionChanged(_ value:Bool) { sessionActive = value }
    public mutating func screenChanged(_ value:Bool) { screenAwake = value }
}

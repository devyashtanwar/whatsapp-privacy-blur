import Foundation
public enum StreamPhase { case idle, starting, running, waitingForStart, stopping, failed }
public enum StreamAction { case none, stop, release, terminate }

/// Serializes start/stop acknowledgements. Selection cannot reopen while either
/// operation is outstanding; repeated requests cannot extend the stop deadline.
public final class StreamLifetime {
    public private(set) var phase: StreamPhase = .idle
    public private(set) var token: UInt64 = 0
    private var lastTime: TimeInterval = 0
    private var stopDeadline: TimeInterval?
    public var canBegin: Bool { phase == .idle }
    public var isStopping: Bool { phase == .waitingForStart || phase == .stopping }
    public init() {}
    public func begin(now: TimeInterval) -> UInt64? {
        guard canBegin, now.isFinite, now >= 0 else { return nil }
        token &+= 1; lastTime = now; stopDeadline = nil; phase = .starting
        return token
    }
    public func requestStop(now: TimeInterval) -> StreamAction {
        guard phase != .idle && phase != .failed else { return .none }
        guard advance(now) else { return fail() }
        switch phase {
        case .starting: phase = .waitingForStart; stopDeadline = now + 5; return .none
        case .running: phase = .stopping; stopDeadline = now + 5; return .stop
        default: return .none
        }
    }
    public func startCompleted(token: UInt64, succeeded: Bool, now: TimeInterval) -> StreamAction {
        guard token == self.token, phase == .starting || phase == .waitingForStart else { return .none }
        guard advance(now) else { return fail() }
        if !succeeded { phase = .idle; stopDeadline = nil; return .release }
        if phase == .waitingForStart { phase = .stopping; return .stop }
        phase = .running; return .none
    }
    public func stopCompleted(token: UInt64, succeeded: Bool, now: TimeInterval) -> StreamAction {
        guard token == self.token, phase == .stopping else { return .none }
        guard advance(now), succeeded else { return fail() }
        phase = .idle; stopDeadline = nil; return .release
    }
    public func poll(now: TimeInterval) -> StreamAction {
        guard isStopping else { return .none }
        guard advance(now), let deadline = stopDeadline, now <= deadline else { return fail() }
        return .none
    }
    private func advance(_ now: TimeInterval) -> Bool {
        guard now.isFinite, now >= lastTime else { return false }
        lastTime = now; return true
    }
    private func fail() -> StreamAction { phase = .failed; return .terminate }
}

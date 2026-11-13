import Foundation
public enum StartupStage: String { case idle, selecting, permission, discovering, authenticating, starting, frameReceived, analyzing, prepared, displayed, paused, failed }
public struct StartupEntry { public let stage: StartupStage; public let time: TimeInterval }
/// Thread-safe, RAM-only trace; no target/content strings or persistence API.
public final class StartupTrace {
    private let lock = NSLock()
    private var stored: [StartupEntry] = []
    public var entries: [StartupEntry] { lock.lock();defer { lock.unlock() };return stored }
    public init() {}
    public func record(_ stage: StartupStage,now: TimeInterval) {
        lock.lock();defer { lock.unlock() }
        guard now.isFinite,now >= 0,now >= (stored.last?.time ?? 0) else { return }
        stored.append(StartupEntry(stage:stage,time:now))
        if stored.count > 32 { stored.removeFirst(stored.count-32) }
    }
}

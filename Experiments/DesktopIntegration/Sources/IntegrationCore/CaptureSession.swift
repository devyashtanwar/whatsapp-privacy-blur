import Foundation
public enum SessionFailure: String { case selectionTimeout, initialFrameTimeout, invalidFrame, clockChanged, targetChanged }
public enum SessionState: Equatable { case idle, selecting, awaitingFrames, capturing, unsupported, paused, failed }
public struct SelectionDescriptor {
    public var windowID: UInt32
    public var pid: Int32
    public var generation: TimeInterval
    public var bundleIdentifier: String
    public var singleWindow: Bool
    public var trusted: Bool
    public init(windowID: UInt32, pid: Int32, generation: TimeInterval, bundleIdentifier: String,
                singleWindow: Bool, trusted: Bool) {
        self.windowID = windowID; self.pid = pid; self.generation = generation
        self.bundleIdentifier = bundleIdentifier; self.singleWindow = singleWindow; self.trusted = trusted
    }
}
/// A one-frame capability checkpoint, not a message-protection engine.
/// No pixel buffer is retained by this state machine.
public final class CaptureSession {
    public private(set) var state: SessionState = .idle
    public private(set) var token: UInt64 = 0
    public private(set) var target: SelectionDescriptor?
    public private(set) var failure: SessionFailure?
    private var lastTime: TimeInterval = 0
    private var deadline: TimeInterval = 0
    public var wantsFrames: Bool { (state == .awaitingFrames || state == .capturing) && target != nil }
    private let continuous: Bool
    public init(continuous: Bool = false) { self.continuous = continuous }
    public func request(settings: BlurSettings, now: TimeInterval) -> UInt64? {
        stop()
        guard settings.needsCapture, now.isFinite, now >= 0 else { return nil }
        lastTime = now; deadline = now+30; state = .selecting
        return token
    }
    public func accept(_ selection: SelectionDescriptor, token: UInt64, now: TimeInterval) -> Bool {
        guard token == self.token, state == .selecting else { return false }
        guard advance(now), selection.singleWindow, selection.trusted,
              selection.windowID != 0, selection.pid > 0, selection.generation.isFinite, selection.generation > 0,
              selection.bundleIdentifier == "net.whatsapp.WhatsApp" else { fail(); return false }
        target = selection; deadline = now + 15; state = .awaitingFrames
        return true
    }
    public func consumeFrame(token: UInt64, capturedAt: TimeInterval, now: TimeInterval, width: Int, height: Int, targetStillTrusted: Bool) -> Bool {
        guard token == self.token, wantsFrames else { return false }
        guard advance(now), (state == .capturing || now <= deadline), capturedAt.isFinite, capturedAt >= 0,
              capturedAt <= now, now - capturedAt <= 0.5, targetStillTrusted,
              width > 0, width <= 4096, height > 0, height <= 4096 else { fail(); return false }
        if continuous { state = .capturing }
        else { stop(); state = .unsupported } // Access-only checkpoint remains available to tests.
        return true
    }
    public func observeIdle(token: UInt64, now: TimeInterval, targetStillTrusted: Bool) -> Bool {
        guard token == self.token,continuous,wantsFrames else { return false }
        guard advance(now),targetStillTrusted else { fail(); return false }
        guard state == .capturing || now <= deadline else { fail(.initialFrameTimeout); return false }
        return true
    }
    public func tick(now: TimeInterval) {
        guard wantsFrames || state == .selecting else { return }
        guard advance(now) else { fail(.clockChanged); return }
        if now > deadline {
            if state == .selecting { fail(.selectionTimeout) }
            else if state == .awaitingFrames { fail(.initialFrameTimeout) }
        }
    }
    public func stop(paused: Bool = false) {
        token &+= 1; target = nil; deadline = 0; failure = nil; state = paused ? .paused : .idle
    }
    private func fail(_ reason: SessionFailure = .invalidFrame) { stop(); state = .failed; failure = reason }
    private func advance(_ now: TimeInterval) -> Bool {
        guard now.isFinite, now >= lastTime else { return false }
        lastTime = now; return true
    }
}

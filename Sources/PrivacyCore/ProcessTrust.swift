import Foundation

public struct ProcessCandidate: Equatable {
    public let pid: Int32
    public let generation: TimeInterval?
    public let bundleIdentifier: String?
    public init(pid: Int32, generation: TimeInterval?, bundleIdentifier: String?) {
        self.pid = pid; self.generation = generation; self.bundleIdentifier = bundleIdentifier
    }
}

public final class TrustedProcessRegistry {
    private var cache: [Int32: (ProcessCandidate, Bool)] = [:]
    public init() {}
    public func allowedPIDs(_ candidates: [ProcessCandidate], validate: (ProcessCandidate) -> Bool) -> Set<Int32> {
        let present = Set(candidates.map(\.pid))
        cache = cache.filter { present.contains($0.key) }
        var allowed = Set<Int32>()
        for candidate in candidates {
            guard candidate.pid > 0, candidate.bundleIdentifier == "net.whatsapp.WhatsApp",
                  let generation = candidate.generation, generation.isFinite, generation > 0 else { continue }
            let valid: Bool
            if let previous = cache[candidate.pid], previous.0 == candidate { valid = previous.1 }
            else {
                valid = validate(candidate)
                cache[candidate.pid] = (candidate, valid)
            }
            if valid { allowed.insert(candidate.pid) }
        }
        return allowed
    }
    public func invalidate() { cache.removeAll() }
    public static func isTrustedForeground(_ pid: Int32?, allowed: Set<Int32>) -> Bool {
        pid.map { allowed.contains($0) } ?? false
    }
}

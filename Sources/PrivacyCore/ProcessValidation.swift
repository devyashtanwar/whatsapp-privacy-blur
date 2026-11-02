import Foundation

public struct ProcessIdentityFailure: Equatable {
    public enum Stage: String { case invalidCandidate, requirementCreation, guestLookup, validityCheck, generationChanged }
    public let stage: Stage
    public let status: Int32?
    public init(stage: Stage, status: Int32? = nil) { self.stage = stage; self.status = status }
    public var summary: String {
        switch stage {
        case .invalidCandidate, .generationChanged: return "Cover inactive — WhatsApp process identity changed or is unavailable"
        case .requirementCreation: return "Cover inactive — identity policy could not be loaded"
        case .guestLookup: return "Cover inactive — WhatsApp process access failed"
        case .validityCheck: return "Cover inactive — WhatsApp code identity verification failed"
        }
    }
}
public enum ProcessValidationResult: Equatable {
    case trusted
    case failed(ProcessIdentityFailure)
}

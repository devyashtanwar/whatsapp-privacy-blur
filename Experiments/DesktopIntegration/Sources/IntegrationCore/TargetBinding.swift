import Foundation
/// Numeric PID/window reuse is not sufficient to authorize presentation of private pixels.
public enum TargetBinding {
    public static func isCurrent(_ frame: FrameBinding,selection: SelectionDescriptor?,token: UInt64,currentGeneration: TimeInterval?,processStillCurrent: Bool) -> Bool {
        guard let selected = selection,let generation = currentGeneration,
              processStillCurrent,selected.trusted,selected.singleWindow,
              selected.bundleIdentifier == "net.whatsapp.WhatsApp",
              frame.session == token,frame.windowID == selected.windowID,frame.processID == selected.pid,
              frame.processGeneration.isFinite,frame.processGeneration > 0,
              frame.processGeneration == selected.generation,frame.processGeneration == generation else { return false }
        return true
    }
}

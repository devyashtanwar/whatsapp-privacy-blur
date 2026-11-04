import AppKit
import LabPolicy

/// Only local fixture pointer motion may acquire hover; a click does not.
public enum FixturePointerEvents {
    public static func location(for event: NSEvent) -> NSPoint? {
        [.mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged].contains(event.type) ? event.locationInWindow : nil
    }
}

/// Raw phases and notifications feed the same per-viewport recovery state.
public enum FixtureScrollEvents {
    public static func signal(phase: NSEvent.Phase, momentum: NSEvent.Phase) -> ScrollSignal? {
        if phase.contains(.began) || phase.contains(.changed) || momentum.contains(.began) || momentum.contains(.changed) { return .move }
        if phase.contains(.mayBegin) { return .prepare }
        if phase.contains(.ended) || phase.contains(.cancelled) || momentum.contains(.ended) || momentum.contains(.cancelled) { return .end }
        if phase.isEmpty && momentum.isEmpty { return .move } // Legacy wheel input.
        return nil // Stationary/no-op observations cannot keep renewing suspension.
    }
}

import AppKit

/// Only local fixture pointer motion may acquire hover; a click does not.
public enum FixturePointerEvents {
    public static func location(for event: NSEvent) -> NSPoint? {
        [.mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged].contains(event.type) ? event.locationInWindow : nil
    }
}

public enum PickerEventAction { case ignore, acceptInitial, stopUnexpected }
public enum PickerEventPolicy {
    public static func action(token: UInt64, currentToken: UInt64, selecting: Bool, hasStream: Bool, replacing: Bool) -> PickerEventAction {
        guard token == currentToken else { return .ignore }
        return !selecting || hasStream || replacing ? .stopUnexpected : .acceptInitial
    }
}

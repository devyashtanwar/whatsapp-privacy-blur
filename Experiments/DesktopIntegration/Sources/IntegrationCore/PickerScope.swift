public enum PickerScope {
    public static func isSingleWindow(windowStyle: Bool, windowIDs: [UInt32], ownerPIDs: [Int32],
                                      displayCount: Int, applicationPIDs: [Int32]) -> Bool {
        guard windowStyle, displayCount == 0, windowIDs.count == 1, ownerPIDs.count == 1,
              windowIDs[0] != 0, ownerPIDs[0] > 0, applicationPIDs.count <= 1 else { return false }
        return applicationPIDs.allSatisfy { $0 == ownerPIDs[0] }
    }
}

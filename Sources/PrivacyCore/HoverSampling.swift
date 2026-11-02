import Foundation
public enum HoverSampling {
    public static func sample(enabled: Bool, location: () -> CGPoint, window: () -> UInt32?) -> (CGPoint, UInt32?) {
        guard enabled else { return (.zero, nil) }
        return (location(), window())
    }
}

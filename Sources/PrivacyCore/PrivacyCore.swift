import Foundation
import CoreGraphics

public struct CoverConfiguration {
    public let enabled: Bool
    public let fullWindow: Bool
    public let hoverReveal: Bool
    public let sidebarWidth: CGFloat
    public init(enabled: Bool = true, fullWindow: Bool = true, hoverReveal: Bool = false, sidebarWidth: CGFloat = 308) {
        self.enabled = enabled
        self.fullWindow = fullWindow
        self.hoverReveal = hoverReveal
        self.sidebarWidth = sidebarWidth.isFinite ? min(500, max(200, sidebarWidth)) : 308
    }
}

public struct TrackedWindow {
    public let id: UInt32
    public let frame: CGRect
    public init(id: UInt32, frame: CGRect) { self.id = id; self.frame = frame }
}

public struct WindowEnvironment {
    public var windows: [TrackedWindow]
    public var primaryDisplayMaxY: CGFloat
    public var targetIsFrontmost: Bool
    public var mouseLocation: CGPoint
    public var hoveredWindowID: UInt32?
    public init(windows: [TrackedWindow], primaryDisplayMaxY: CGFloat, targetIsFrontmost: Bool, mouseLocation: CGPoint) {
        self.windows = windows
        self.primaryDisplayMaxY = primaryDisplayMaxY
        self.targetIsFrontmost = targetIsFrontmost
        self.mouseLocation = mouseLocation
    }
}

public enum WindowMetadataDecoder {
    public static func decode(_ records: [[String: Any]], ownerPIDs: Set<Int32>) -> [TrackedWindow] {
        records.compactMap { record in
            guard let pid = record[kCGWindowOwnerPID as String] as? NSNumber,
                  let exactPID = Int32(exactly: pid.int64Value), ownerPIDs.contains(exactPID),
                  let layer = record[kCGWindowLayer as String] as? NSNumber, layer.intValue == 0,
                  let id = record[kCGWindowNumber as String] as? NSNumber,
                  let exactID = UInt32(exactly: id.int64Value), exactID != 0,
                  let alpha = record[kCGWindowAlpha as String] as? NSNumber,
                  alpha.doubleValue.isFinite, alpha.doubleValue > 0,
                  let bounds = record[kCGWindowBounds as String] as? [String: Any],
                  let frame = CGRect(dictionaryRepresentation: bounds as CFDictionary) else { return nil }
            return TrackedWindow(id: exactID, frame: frame)
        }
    }
}

public struct CoverPlan: Equatable {
    public let windowID: UInt32
    public let regions: [CGRect]
    public let revealed: Bool
}

public protocol WindowSource: AnyObject { func snapshot(includeHover: Bool) -> WindowEnvironment }
public protocol CoverSink: AnyObject { func apply(_ plans: [CoverPlan]) }

public enum CoveragePlanner {
    public static func plans(configuration: CoverConfiguration, environment: WindowEnvironment) -> [CoverPlan] {
        guard configuration.enabled, environment.primaryDisplayMaxY.isFinite else { return [] }
        var seen = Set<UInt32>()
        return environment.windows.compactMap { window in
            let f = window.frame
            guard window.id != 0,
                  f.origin.x.isFinite, f.origin.y.isFinite,
                  f.size.width.isFinite, f.size.height.isFinite,
                  f.size.width > 0, f.size.height > 0,
                  f.maxX.isFinite, f.maxY.isFinite,
                  seen.insert(window.id).inserted else { return nil }
            // Quartz's origin is at the primary display's top-left. AppKit's
            // global origin stays on the primary display, even on other monitors.
            let y = environment.primaryDisplayMaxY - f.maxY
            guard y.isFinite else { return nil }
            let frame = CGRect(x: f.minX, y: y, width: f.width, height: f.height)
            var regions = [frame]
            if !configuration.fullWindow {
                let width = min(configuration.sidebarWidth, frame.width)
                regions = [CGRect(x: frame.minX, y: frame.minY, width: width, height: frame.height)]
                if width < frame.width {
                    let height = min(60, frame.height)
                    regions.append(CGRect(x: frame.minX + width, y: frame.maxY - height,
                                          width: frame.width - width, height: height))
                }
            }
            let revealed = configuration.hoverReveal && environment.targetIsFrontmost &&
                environment.hoveredWindowID == window.id &&
                regions.contains { $0.contains(environment.mouseLocation) }
            return CoverPlan(windowID: window.id, regions: regions, revealed: revealed)
        }
    }
}

public final class PrivacyCoordinator {
    private let source: WindowSource
    private let sink: CoverSink
    private var configuration = CoverConfiguration(enabled: false)
    private let confinementAllowed: Bool
    public private(set) var isMonitoring = false
    public init(source: WindowSource, sink: CoverSink, confinementAllowed: Bool = false) {
        self.source = source; self.sink = sink; self.confinementAllowed = confinementAllowed
    }
    public func update(configuration: CoverConfiguration, targetRunning: Bool, suspended: Bool) {
        self.configuration = configuration
        isMonitoring = confinementAllowed && configuration.enabled && targetRunning && !suspended
        poll()
    }
    public func poll() {
        guard isMonitoring else {
            sink.apply([])
            return
        }
        sink.apply(CoveragePlanner.plans(configuration: configuration, environment: source.snapshot(includeHover: configuration.hoverReveal)))
    }
}

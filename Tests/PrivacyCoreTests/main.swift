import Foundation
import Darwin
import CoreGraphics
import PrivacyCore

struct PrivacyCoreTests {
    // Removing the monitoring guard would read window metadata after Disable or suspension.
    func testDisabledAndSuspendedNeverReadMetadata() {
        let source = Source()
        let sink = Sink()
        let coordinator = PrivacyCoordinator(source: source, sink: sink, confinementAllowed: true)
        coordinator.update(configuration: .init(enabled: false), targetRunning: true, suspended: false)
        coordinator.poll()
        expect((source.reads) == (0))
        expect((sink.plans.isEmpty))
        coordinator.update(configuration: .init(), targetRunning: true, suspended: true)
        coordinator.poll()
        expect((source.reads) == (0))
    }

    func testEnableAfterStartingDisabledResumesAndDisableClearsAllCovers() {
        let source = Source()
        let sink = Sink()
        let coordinator = PrivacyCoordinator(source: source, sink: sink, confinementAllowed: true)
        coordinator.update(configuration: .init(enabled: false), targetRunning: true, suspended: false)
        coordinator.update(configuration: .init(), targetRunning: true, suspended: false)
        expect((coordinator.isMonitoring))
        expect((source.reads) == (1))
        expect((sink.plans.count) == (1))
        coordinator.update(configuration: .init(enabled: false), targetRunning: true, suspended: false)
        let reads = source.reads
        coordinator.poll()
        expect((source.reads) == (reads))
        expect(!(coordinator.isMonitoring))
        expect((sink.plans.isEmpty))
    }

    func testTargetExitClearsCoversAndResumeRecomputes() {
        let source = Source()
        let sink = Sink()
        let coordinator = PrivacyCoordinator(source: source, sink: sink, confinementAllowed: true)
        coordinator.update(configuration: .init(), targetRunning: true, suspended: false)
        coordinator.update(configuration: .init(), targetRunning: false, suspended: false)
        expect((sink.plans.isEmpty))
        expect(!(coordinator.isMonitoring))
        source.environment.windows = [.init(id: 22, frame: CGRect(x: 0, y: 10, width: 500, height: 400))]
        coordinator.update(configuration: .init(), targetRunning: true, suspended: false)
        expect((sink.plans.map(\.windowID)) == ([22]))
    }

    // A foreground-only filter would leave a still-visible background window exposed.
    func testBackgroundWindowsStayCoveredAndHoverRevealResetsOnFocusLoss() {
        var environment = Source().environment
        environment.mouseLocation = CGPoint(x: 110, y: 700)
        environment.hoveredWindowID = 1
        let configuration = CoverConfiguration(hoverReveal: true)
        environment.targetIsFrontmost = true
        expect((CoveragePlanner.plans(configuration: configuration, environment: environment).first?.revealed == true))
        environment.targetIsFrontmost = false
        let background = CoveragePlanner.plans(configuration: configuration, environment: environment)
        expect((background.count) == (1))
        expect(!(background.first?.revealed == true))
    }

    func testDefaultCoversEntireWindowWithoutHoverReveal() {
        var environment = Source().environment
        environment.mouseLocation = CGPoint(x: 110, y: 700)
        let plans = CoveragePlanner.plans(configuration: .init(), environment: environment)
        expect((plans.first?.regions) == ([CGRect(x: 100, y: 280, width: 800, height: 500)]))
        expect(!(plans.first?.revealed == true))
    }

    func testMultipleWindowsAndNegativeDisplayOrigins() {
        var environment = Source().environment
        environment.windows.append(.init(id: 2, frame: CGRect(x: -1280, y: -200, width: 700, height: 600)))
        let plans = CoveragePlanner.plans(configuration: .init(), environment: environment)
        expect((plans.map(\.windowID)) == ([1, 2]))
        expect((plans.dropFirst().first?.regions) == ([CGRect(x: -1280, y: 680, width: 700, height: 600)]))
    }

    func testSidebarClampsToSmallWindowsAndHeaderStaysInsideWindow() {
        var environment = Source().environment
        environment.windows = [.init(id: 1, frame: CGRect(x: 10, y: 20, width: 150, height: 40))]
        let plans = CoveragePlanner.plans(configuration: .init(fullWindow: false, sidebarWidth: 500), environment: environment)
        expect((plans.first?.regions) == ([CGRect(x: 10, y: 1020, width: 150, height: 40)]))
        environment.windows = [.init(id: 1, frame: CGRect(x: 0, y: 0, width: 800, height: 500))]
        let partial = CoveragePlanner.plans(configuration: .init(fullWindow: false, sidebarWidth: 300), environment: environment)
        expect((partial.first?.regions) == ([
            CGRect(x: 0, y: 580, width: 300, height: 500),
            CGRect(x: 300, y: 1020, width: 500, height: 60)
        ]))
    }

    func testInvalidFramesAndDuplicateIDsAreRejected() {
        var environment = Source().environment
        environment.windows += [
            .init(id: 1, frame: .zero),
            .init(id: 3, frame: CGRect(x: 0, y: 0, width: -1, height: 500)),
            .init(id: 4, frame: CGRect(x: CGFloat.infinity, y: 0, width: 800, height: 500)),
            .init(id: 5, frame: .zero)
        ]
        expect((CoveragePlanner.plans(configuration: .init(), environment: environment).map(\.windowID)) == ([1]))
        environment.primaryDisplayMaxY = .nan
        expect((CoveragePlanner.plans(configuration: .init(), environment: environment).isEmpty))
    }

    func testInvalidWidthUsesSafeFallbackAndSettingsAreBounded() {
        expect((CoverConfiguration(sidebarWidth: .nan).sidebarWidth) == (308))
        expect((CoverConfiguration(sidebarWidth: .infinity).sidebarWidth) == (308))
        expect((CoverConfiguration(sidebarWidth: -500).sidebarWidth) == (200))
        expect((CoverConfiguration(sidebarWidth: 5000).sidebarWidth) == (500))
    }

    func testHoverDoesNotRevealWindowBehindAnotherWindow() {
        var environment = Source().environment
        environment.mouseLocation = CGPoint(x: 110, y: 700)
        environment.hoveredWindowID = 99
        expect(CoveragePlanner.plans(configuration: .init(hoverReveal: true), environment: environment).first?.revealed == false)
    }

    func testMetadataDecoderRejectsOtherAppsUtilityWindowsAndMalformedRecords() {
        let valid: [String: Any] = [
            kCGWindowOwnerPID as String: 42, kCGWindowNumber as String: 7,
            kCGWindowLayer as String: 0, kCGWindowAlpha as String: 1,
            kCGWindowBounds as String: ["X": 10, "Y": 20, "Width": 800, "Height": 500]
        ]
        var otherApp = valid; otherApp[kCGWindowOwnerPID as String] = 999
        var utility = valid; utility[kCGWindowLayer as String] = 1
        var invisible = valid; invisible[kCGWindowAlpha as String] = 0
        var invalidID = valid; invalidID[kCGWindowNumber as String] = -1
        var malformed = valid; malformed.removeValue(forKey: kCGWindowBounds as String)
        let decoded = WindowMetadataDecoder.decode([valid, otherApp, utility, invisible, invalidID, malformed], ownerPIDs: [42])
        expect(decoded.map(\.id) == [7])
        expect(decoded.first?.frame == CGRect(x: 10, y: 20, width: 800, height: 500))
    }

    private final class Source: WindowSource {
        var reads = 0
        var environment = WindowEnvironment(
            windows: [.init(id: 1, frame: CGRect(x: 100, y: 300, width: 800, height: 500))],
            primaryDisplayMaxY: 1080,
            targetIsFrontmost: true,
            mouseLocation: .zero
        )
        func snapshot(includeHover: Bool) -> WindowEnvironment { reads += 1; return environment }
    }

    private final class Sink: CoverSink {
        var plans: [CoverPlan] = []
        func apply(_ plans: [CoverPlan]) { self.plans = plans }
    }
}


// A tiny command-line harness keeps these pure policy tests runnable with Apple's
// Command Line Tools, without XCTest/Xcode or compiler macro plugins.
var failures = 0
var assertions = 0
func expect(_ condition: @autoclosure () -> Bool, file: StaticString = #filePath, line: UInt = #line) {
    assertions += 1
    if !condition() {
        failures += 1
        print("FAIL: \(file):\(line)")
    }
}
let suite = PrivacyCoreTests()
let checks: [(String, () -> Void)] = [
    ("authenticated processes", processTrustTests),
    ("capability boundary", capabilityTests),
    ("startup and hover minimization", startupAndHoverTests),
    ("disabled/suspended", suite.testDisabledAndSuspendedNeverReadMetadata),
    ("enable/disable", suite.testEnableAfterStartingDisabledResumesAndDisableClearsAllCovers),
    ("target exit", suite.testTargetExitClearsCoversAndResumeRecomputes),
    ("background hover", suite.testBackgroundWindowsStayCoveredAndHoverRevealResetsOnFocusLoss),
    ("full coverage default", suite.testDefaultCoversEntireWindowWithoutHoverReveal),
    ("display coordinates", suite.testMultipleWindowsAndNegativeDisplayOrigins),
    ("sidebar clamping", suite.testSidebarClampsToSmallWindowsAndHeaderStaysInsideWindow),
    ("invalid geometry", suite.testInvalidFramesAndDuplicateIDsAreRejected),
    ("width bounds", suite.testInvalidWidthUsesSafeFallbackAndSettingsAreBounded),
    ("occluded hover", suite.testHoverDoesNotRevealWindowBehindAnotherWindow),
    ("metadata decoding", suite.testMetadataDecoderRejectsOtherAppsUtilityWindowsAndMalformedRecords)
]
for (name, check) in checks { print("Running \(name)"); check() }
print("\(checks.count) core checks, \(assertions) assertions, \(failures) failures")
exit(failures == 0 ? 0 : 1)

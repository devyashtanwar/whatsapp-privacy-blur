import Foundation
import PrivacyCore

func startupAndHoverTests() {
    final class Source: WindowSource {
        var reads = 0
        var hoverReads = 0
        func snapshot(includeHover: Bool) -> WindowEnvironment {
            reads += 1
            let (mouse, hit) = HoverSampling.sample(enabled: includeHover,
                location: { self.hoverReads += 1; return CGPoint(x: 1, y: 1) },
                window: { self.hoverReads += 1; return 1 })
            var result = WindowEnvironment(windows: [], primaryDisplayMaxY: 1080, targetIsFrontmost: true, mouseLocation: mouse)
            result.hoveredWindowID = hit
            return result
        }
    }
    final class Sink: CoverSink {
        var plans: [CoverPlan] = []
        func apply(_ plans: [CoverPlan]) { self.plans = plans }
    }
    let source = Source(), sink = Sink()
    let denied = PrivacyCoordinator(source: source, sink: sink)
    denied.update(configuration: .init(hoverReveal: true), targetRunning: true, suspended: false)
    denied.poll()
    expect(source.reads == 0 && sink.plans.isEmpty && !denied.isMonitoring)
    let allowed = PrivacyCoordinator(source: source, sink: sink, confinementAllowed: true)
    allowed.update(configuration: .init(), targetRunning: true, suspended: false)
    expect(source.reads == 1 && source.hoverReads == 0)
    allowed.update(configuration: .init(hoverReveal: true), targetRunning: true, suspended: false)
    expect(source.hoverReads == 2)
    let reads = source.reads
    allowed.update(configuration: .init(enabled: false, hoverReveal: true), targetRunning: true, suspended: false)
    allowed.poll()
    expect(source.reads == reads && source.hoverReads == 2)
    allowed.update(configuration: .init(hoverReveal: true), targetRunning: true, suspended: true)
    allowed.poll()
    expect(source.reads == reads && source.hoverReads == 2)
}

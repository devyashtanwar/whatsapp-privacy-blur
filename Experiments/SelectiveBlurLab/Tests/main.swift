import Foundation
import CoreGraphics
import Darwin
import LabPolicy
var checks = 0
var failures = 0
func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
    checks += 1
    if !condition() { failures += 1; print("FAIL: \(message)") }
}
let name = CGRect(x: 60, y: 12, width: 180, height: 18)
let preview = Region(1, CGRect(x: 60, y: 40, width: 220, height: 20))
func plan(_ regions: [Region], _ evidence: Evidence = .instrumentedFixture, observed: Double = 10, now: Double = 10) -> GeometryPlan {
    RegionPlanner.plan(regions, excluding: [name], within: CGRect(x: 0, y: 0, width: 1200, height: 3000), evidence: evidence, observedAt: observed, now: now)
}
expect(plan([preview]).regions == [preview], "preview stays blurred without masking name")
expect(plan([Region(1, name)]).state == .invalid, "name intersection must invalidate masks")
expect(plan([preview, preview]).state == .invalid, "duplicate IDs invalidate the complete frame")
expect(plan([Region(1, .zero)]).state == .invalid, "zero-sized masks cannot claim readiness")
expect(plan([Region(1, CGRect(x: Double.nan, y: 0, width: 10, height: 10))]).state == .invalid, "NaN bounds rejected")
expect(plan([preview], .windowBoundsOnly).state == .unsupported, "window bounds do not identify messages")
expect(plan([preview], observed: 9, now: 10).state == .stale, "old layout cannot report ready")
expect(plan([preview], observed: 11, now: 10).state == .stale, "future/invalid clock cannot report ready")
expect(plan([preview], observed: 10, now: .nan).state == .stale, "invalid clock rejected")
expect(plan([]).state == .unsupported, "no regions cannot report ready")
for count in [1, 10, 30] {
    let rows = (0..<count).map { Region($0, CGRect(x: 60, y: 40 + $0 * 80, width: 220, height: 20)) }
    expect(plan(rows).regions.count == count, "independent region count \(count)")
}
// Same window rectangle, different content scroll. Window-only evidence must reject
// both; the instrumented fixture provider must supply fresh actual region bounds.
let moved = Region(1, CGRect(x: 60, y: 120, width: 220, height: 20))
expect(plan([moved]).regions == [moved], "fresh changed coordinates replace prior row geometry")
expect(plan([moved], .windowBoundsOnly).regions.isEmpty, "no fixed-grid fallback after scrolling")
let hover = HoverRecovery()
hover.setPermitted(true)
expect(hover.pointer(item: 1, position: CGPoint(x: 1, y: 1), now: 10) == 1, "initial physical hover reveals")
hover.scroll(.move, in: 0, now: 10.01)
expect(hover.revealedID == nil, "movement revokes before rendering")
hover.scroll(.prepare, in: 1, now: 10.02)
hover.scroll(.end, in: 0, now: 10.03)
expect(hover.pointer(item: 2, position: CGPoint(x: 2, y: 1), now: 10.04) == nil, "moving content remains blurred")
expect(hover.tick(now: 10.3) == nil, "missing end recovers eligibility without auto reveal")
expect(!hover.waitingForScroll, "unmatched source cannot lock indefinitely")
expect(hover.pointer(item: 2, position: CGPoint(x: 3, y: 1), now: 10.31) == 2, "direct intentional entry recovers without blank space")
hover.scroll(.end, in: 1, now: 10.32)
expect(hover.revealedID == 2, "late end is idempotent")
hover.invalidate()
expect(hover.pointer(item: 3, position: CGPoint(x: 3, y: 1), now: 10.33) == nil, "content changing under stationary pointer does not reveal")
expect(hover.pointer(item: 3, position: CGPoint(x: 4, y: 1), now: 10.34) == 3, "new motion may reveal same-position content after invalidation")
hover.setPermitted(false)
expect(hover.revealedID == nil, "focus/permission loss reblurs")
hover.setPermitted(true)
expect(hover.pointer(item: 3, position: CGPoint(x: 4, y: 1), now: 10.4) == nil, "focus regain stationary sample cannot renew")
expect(hover.pointer(item: 3, position: CGPoint(x: 5, y: 1), now: 10.5) == 3, "deliberate hover after focus regain works")
expect(hover.tick(now: 12.5) == nil, "two-second lease expires")
expect(hover.pointer(item: 3, position: CGPoint(x: 6, y: 1), now: 12.6) == nil, "expiry cannot renew inside same item")
expect(hover.pointer(item: 2, position: CGPoint(x: 7, y: 1), now: 12.7) == 2, "coalesced entry to a different message counts as exit")
hover.exit(now: 12.8)
expect(hover.pointer(item: 3, position: CGPoint(x: 7, y: 1), now: 12.9) == 3, "actual root exit/reentry recovers")
expect(hover.tick(now: .nan) == nil, "invalid time cannot reveal")
let legacy = HoverRecovery(); legacy.setPermitted(true)
for time in [20.0, 20.04, 20.08, 20.12] { legacy.scroll(.move, in: 0, now: time) }
expect(legacy.pointer(item: 1, position: .zero, now: 20.2) == nil, "ongoing legacy movement remains blocked")
expect(legacy.tick(now: 20.4) == nil, "settling legacy input does not reveal")
expect(legacy.pointer(item: 1, position: CGPoint(x: 1, y: 0), now: 20.41) == 1, "legacy input recovers without an end pair")
print("\(checks) selective-region assertions, \(failures) failures")
exit(failures == 0 ? 0 : 1)

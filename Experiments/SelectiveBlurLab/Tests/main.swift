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
let lease = RevealLease()
expect(lease.update(item: 1, active: true, epoch: 1, now: 10) == 1, "hover reveals one item")
expect(lease.update(item: 1, active: true, epoch: 1, now: 12) == nil, "reveal expires even while stationary")
expect(lease.update(item: 1, active: true, epoch: 1, now: 13) == nil, "expired hover cannot renew without leaving")
expect(lease.update(item: nil, active: true, epoch: 1, now: 13) == nil, "pointer leave reblurs")
expect(lease.update(item: 2, active: true, epoch: 1, now: 14) == 2, "new item gets independent lease")
expect(lease.update(item: 2, active: false, epoch: 1, now: 14.1) == nil, "focus loss immediately reblurs")
expect(lease.update(item: 2, active: true, epoch: 2, now: 14.2) == nil, "layout change invalidates existing hover until exit")
expect(lease.update(item: nil, active: true, epoch: 2, now: 15) == nil, "exit resets layout invalidation")
expect(lease.update(item: 2, active: true, epoch: 2, now: 15.1) == 2, "reentry can reveal after layout settles")
expect(lease.update(item: 2, active: true, epoch: 2, now: .nan) == nil, "invalid clock cannot reveal")
// The UI deliberately stops pointer sampling while inactive. A nil hit during
// suspension is not evidence that the pointer physically left the old item.
let suspensionLease = RevealLease()
expect(suspensionLease.update(item: 1, active: true, epoch: 1, now: 20) == 1, "initial integration hover")
expect(suspensionLease.update(item: nil, active: false, epoch: 1, now: 20.1) == nil, "inactive UI supplies no hit")
expect(suspensionLease.update(item: 1, active: true, epoch: 1, now: 20.2) == nil, "focus regain cannot reveal stationary pointer")
expect(suspensionLease.update(item: nil, active: true, epoch: 1, now: 20.3) == nil, "active pointer exit clears suspension")
expect(suspensionLease.update(item: 1, active: true, epoch: 1, now: 20.4) == 1, "active reentry may reveal")
// A scroll/layout callback must revoke the current lease before any movement,
// even when no new pointer sample or timer tick has occurred.
let movementLease = RevealLease()
expect(movementLease.update(item: 1, active: true, epoch: 1, now: 30) == 1, "initial movement-test reveal")
movementLease.suspend()
expect(movementLease.update(item: 2, active: true, epoch: 1, now: 30.01) == nil, "scroll cannot reveal the next item under a stationary pointer")
expect(movementLease.update(item: 1, active: true, epoch: 1, now: 30.02) == nil, "movement revokes old reveal without a timer")
expect(movementLease.update(item: nil, active: true, epoch: 1, now: 30.03) == nil, "observed pointer exit clears movement latch")
expect(movementLease.update(item: 2, active: true, epoch: 1, now: 30.04) == 2, "physical reentry after movement may reveal")
print("\(checks) selective-region assertions, \(failures) failures")
exit(failures == 0 ? 0 : 1)

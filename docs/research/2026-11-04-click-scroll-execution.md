# Click/scroll correction execution record

Plan: docs/research/2026-11-04-click-flash-investigation.md.
Baseline: PR #5 head 7aafa16435d00b45cd4771f9906f04645b2ae75a. User approved execution and existing draft PR workflow. Work stays in the existing agent-owned checkout/branch. No desktop/browser control, visible GUI launch, installed-app change or permission grant.

Ruling: Replace the lab's independent patch windows with in-document blur surfaces, as Task 2A proposes. This removes independent click ordering and screen-space geometry polling from the lab rather than trying to repair those symptoms with a faster timer. Cost: the public withinWindow material can differ visually and this does not demonstrate cross-process WhatsApp compatibility.

Task 1 evidence: User reports actual click flashes and scroll exposure. Source shows independent patch windows plus 50 ms geometry polling. Existing view-less policy tests could not test presentation. New tests use actual hidden NSView/NSClipView trees, never create a window and never capture pixels. Scaffold failed 54/80 assertions; this is test boundary RED, not a claim that the original WindowServer failure was reproduced by the agent. No optional diagnostic logging or recording was added because the structural risks were addressed directly; original per-frame causality remains uncertified.

Task 2A implementation: MessageBlurSurface contains content and a click-through NSVisualEffectView with matching autoresizing bounds, withinWindow blending and active material state. All synthetic offscreen items are created with blur present before being attached to the document. Scrolling uses the same view transform/ancestor clipping, without mask movement/recreation on a timer. Ordinary clicks do not change blur ordering or presentation of unrelated items.

Tasks 3–4: RevealLease.suspend() revokes a lease without pointer movement; two policy regressions failed before implementation. Local fixture mouse events alone acquire hover. Clip scroll/bounds hooks and bounds/live-scroll notifications cancel reveal; input gesture/momentum tokens prevent reveal during observed scroll activity. Losing key/app focus restores all blurs and latches exit/reentry; visible background content remains blurred. Unsupported mode remains an explicit user selection that shows no masking and reports not protected.

A real NSClipView regression found scroll(to:) did not dispatch the initial setBoundsOrigin hook; two view assertions failed. Added a direct scroll(to:) pre-movement hook, then both passed. Initial hover tests were clarified to supply the explicit pointer exit required after enabling hover. No timer acquires hover or resets geometry. Remaining timer is expiry only.

Current evidence: 35 pure-policy assertions and 87 actual hidden AppKit view/event assertions pass. View tests cover rapid fractional/reversing scroll without timer ticks, incoming/partially visible masks, shared clipping, resizing, retained view identities, per-item reveal, focus loss/regain, overlapping scroll tokens and hit-test pass-through.

Ruling: User-operated visual regression is still required. Hidden view-tree checks prove geometry/state behavior but cannot prove compositor pixels, native-feel scrolling, live interaction or withinWindow material unreadability. Cost: this update cannot yet be described as visually fixed or production ready. The existing actual-WhatsApp region-discovery and cross-process rendering gates remain open.

Final source review, release builds, signed-artifact checks and full suite results will be appended below. No planned live visual gate is marked complete.

Final review found one important integrated-path omission: otherMouseDragged was not routed, so an extra-button drag could leave the prior item revealed until timeout. Extracted the actual local NSEvent classifier, observed its regression fail on that event, then included it. The event classifier is used by PointerWindow, not a test-only copy. No other critical/important source issues were identified.

Final: Ruling: Live event delivery, gesture/momentum handoff, minimization, compositor secrecy and material unreadability cannot be certified by hidden view tests. Keep the draft and user visual acceptance gate. Cost: this is an implemented candidate correction, not a claim that the user's pixel-level reproduction has passed or that external WhatsApp is supported.

Final verification: 35 policy + 87 hidden AppKit view/event assertions, zero failures. Production suite: 14 core checks / 77 assertions, zero failures; 57 Python tests, zero failures and 3 explicit opt-in fixture skips (Store, Developer ID and live PID not supplied). All four production and all five lab signed-artifact checks ran. Both release builds and signature/capability checks pass. Shell syntax and whitespace checks pass. The final reviewer issue was verified RED (one otherMouseDragged failure) then GREEN; no additional critical/important findings or deferred minors. No visible window, browser, installed app, permission or OS setting was operated/changed by the agent.

Implemented candidate correction is ready for source review and user-run visual regression. The user's original click/scroll pixel-level reproduction is not marked passed. PR #5 remains draft; production integration remains gated.

CI follow-up: macOS 14's real AppKit view test failed exact child bounds after a parent resize, while the local macOS SDK/run passed that integer case. Added fractional-size regressions and exact frame diagnostics rather than weakening the assertion. MessageBlurSurface now explicitly synchronizes content/effect bounds in resizeSubviews instead of relying solely on autoresizing-mask rounding. Final CI confirmation follows; the first published run correctly remains recorded as failed.

Resize follow-up verification: fractional resize regression reproduced locally with 3 failed assertions (for example 320.0-point blur versus 320.25-point content). After explicit bounds synchronization, 35 policy and 90 hidden view/event assertions pass. Reviewed lab release build and all 57 Python suite checks complete with zero failures and the same 3 explicit opt-in fixture skips. macOS 14 CI rerun is required before final success claim.

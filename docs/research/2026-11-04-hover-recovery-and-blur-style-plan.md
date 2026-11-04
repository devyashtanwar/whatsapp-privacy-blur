# Hover recovery investigation and blur appearance plan

Initial status: source investigation, isolated synthetic state reproduction and proposed changes only. See [execution record](2026-11-04-hover-recovery-execution.md) for subsequent authorized implementation. No production/lab source edits, installed-app changes, browser/desktop operation, visible GUI, permission changes or new PR in this turn.

## User acceptance and remaining defects

The user reports that the current lab scrolls without partial disclosure and clicks no longer cause global exposure. Preserve those gains. The newly reported failure is hover reveal becoming unavailable after scrolling, with window switching restoring it. Clicking may coincide with the failure, but click causality is not established.

The lab's materials and controls are feasibility UI, not a selected production design. The user wants a soft Gaussian appearance, recognizable message/bubble structure, subtle hierarchy and a perceived 60–70% translucent treatment. Keep names/navigation clear. This aesthetic requirement must not be implemented by showing sharp message text through a partly transparent cover.

## Code findings

1. **Scroll locks have no recovery path except matching terminal events or focus loss.** BlurPresentation.swift (currently MessageBlurSurface.swift:43,64–66,82–83) stores integer tokens in a set and rejects every pointer event while any token remains. The fixture simultaneously inserts per-pane live-scroll tokens 0/1 and raw gesture/momentum tokens 100/101 (main.swift:104–112,182–189). Ending one source does not finish another. There is no settled-state reconciliation or bounded recovery if a source lacks its expected terminal callback. Losing focus explicitly clears the entire set (50–54), explaining how a focus cycle can restore reveal.
2. **Pointer exit is defined too narrowly.** Every layout/scroll boundary suspends RevealLease. It remains suspended until update receives item:nil while active (Regions.swift:40–53). Moving directly between message regions, or having pointer events coalesced across a narrow gap, does not necessarily produce that nil sample. Deliberate post-scroll movement can therefore be rejected indefinitely until the pointer crosses recognized blank space.
3. **Redundant lifecycle signals can revoke a newly eligible hover.** beginScroll/endScroll always call layoutWillChange; the end path revokes even if that token was absent. Bounds notifications, raw phases, live-scroll notifications and clip overrides can all describe one movement. They are not normalized into one session, and duplicate/out-of-order callbacks need explicit tests.
4. **Clicks are not direct reveal inputs.** FixturePointerEvents intentionally ignores mouse-down events. A click may coincide with focus, layout or preparatory trackpad phases, but source inspection does not show a click itself inserting a lock. Do not claim that clicking is a confirmed independent cause. Apple documents mayBegin as preparatory and phase/momentumPhase as different signals; legacy/momentum events can have phase none.
5. Existing tests use deliberately balanced begin/end calls and explicit nil pointer samples. They verify safety but miss incomplete event streams and ordinary direct post-scroll hover recovery. Passing tests did not establish usability of these event paths.

## Isolated reproduction evidence

A temporary separate Swift package copied the current LabPolicy/LabViews source and used two synthetic hidden NSView surfaces. It never created a window, queried WhatsApp or sent input to the desktop. The repository source was not edited.

Observed outcomes:
- Initial intentional hover reveals: true.
- beginScroll(100), beginScroll(0), endScroll(0), then real exit/reentry samples: all items still blocked.
- Focus false -> true followed by exit/reentry: reveal recovers.
- Balanced scrolling followed directly by a nonnil message hit: reveal still blocked.
- Active nil/blank-space hit followed by message entry: reveal recovers.

This deterministically reproduces the two state failure mechanisms. It does not prove which unmatched phase/notification sequence occurs on the user's hardware. The next change must exercise normalized raw events plus controller integration, not assume token 100 specifically is always the offender.

## Proposed task 1 — Regressions and bounded local diagnostics

Files: lab ViewTests, LabPolicy tests and the existing local event adapter. Keep tests and diagnostics synthetic-only.

Before implementing, add failing end-to-end reducer/controller cases for:
- Normal trackpad gesture followed by momentum; preparatory mayBegin followed by ended/cancelled without movement.
- Duplicate, missing, late and reordered raw/live-scroll endings; ending one stream must neither strand another forever nor prematurely authorize reveal while content is moving.
- Legacy wheel and programmatic/keyboard bounds movement with no live-scroll start/end pair.
- Pointer remains stationary throughout scrolling and afterward: never reveal automatically.
- Scrolling settles, then the user deliberately moves onto a message: reveal must recover without switching windows or needing a sampled blank gap.
- Coalesced movement from message A to B after scrolling; expiry and focus regain remain bounded and safe.
- Click, scroll, hover, focus loss/regain, and scroll again; confirm that one region is the maximum reveal and all other regions remain blurred.
- Idle expiry timer never acquires a fresh hover.

If the actual live sequence remains ambiguous, add a bounded opt-in in-memory diagnostic panel to the lab: last owned scroll source/phase, last bounds movement, local pointer-motion sequence, block reason and time since actual movement. No message text, typed keys, persistent logs, recording, network, global input hooks or external app data. A readable status such as 'Reveal paused while scrolling' is preferable to silently ignoring hover; developer details stay out of the intended product UI.

## Proposed task 2 — One per-pane scroll state, not independent permanent locks

Introduce a focused LabPolicy scroll/reveal reducer used by the real event adapter. Normalize raw phases, momentum and NSScrollView notifications into one scoped session per synthetic viewport. Use named events/reasons rather than magic integer locks.

Suggested states: idle, direct scrolling, momentum, settling. Record actual movement/phase timestamps with a monotonic clock and distinguish preparation from content motion. Treat didEnd tracking as a transition, not proof that momentum is over. Handle cancellation and source changes explicitly. Duplicate/obsolete terminal events should be idempotent rather than resetting a new hover.

Add conservative settled-state reconciliation for an incomplete stream. A proposed starting quiet interval is 150 ms after the last actual movement, subject to hardware testing; it is not a privacy guarantee or fixed production decision. Do not extend the lock forever merely because an old marker or no-op callback exists. Repeated real movement always revokes reveal before moving content through the existing clip hooks.

Crucial constraint: recovery from a stale marker may only restore eligibility for a new intentional hover. It must not reveal a stationary item on a timeout. Require a newer deliberate local pointer movement after the settled transition. If movement resumes, synchronously restore blur again. Focus switching must not be the required recovery mechanism.

Keep content-attached blur rendering, exact fractional bounds and shared clipping unchanged. A timer may maintain hover eligibility/expiry, but must not become a geometry-following renderer or an automatic reveal trigger.

## Proposed task 3 — Distinguish physical pointer movement from content moving beneath it

Replace the blanket requiresExit reset with explicit entry/intent state after suspension. The actual local NSEvent adapter must supply movement position/sequence/time and suspension reason; a bounds notification is not a pointer event.

Once scrolling has settled, a genuine newer pointer movement into the current message may start its normal bounded reveal. Do not require a blank-space sample: direct entry into another item or coalesced movement must work. A stationary pointer over newly arriving content remains blurred. A click must not create a reveal or renew an expired lease. Preserve all mouse drag types already covered by the regression suite.

Keep focus loss and stale/unsupported geometry conservative. Retain the existing reveal duration unless the user separately changes that behavior. Define expiry re-entry separately from post-scroll recovery so an expired item cannot renew on a timer or repeated stale samples.

Visual acceptance matrix: hover before any scroll; hover immediately after slow/fast scroll, inertia, reversal and scrollbar drag; direct message-to-message movement; clicks in composer/messages/blank areas; windows switching; repeat on supported trackpad/mouse configurations. Success requires consistent recovery without returning to global click flashes or partial scroll exposure.

## Proposed task 4 — Appearance direction after the functional fix

The existing Popover/HUD/Sheet selector is a lab tool, not the intended final UI. Public NSVisualEffectView materials are not a specified Gaussian radius. The production visual direction still needs approval using invented chats.

Proposed appearance:
- Preserve message-bubble shape, spacing, alignment and background identity.
- Use soft local blur over content with a quiet, theme-aware tint; avoid heavy grey cards or black covers.
- Keep contact names, avatars, navigation, header and composer sharp.
- Use consistent corner treatment and restrained borders, with readability hierarchy coming from layout and metadata rather than stronger opacity over everything.
- Limit any reveal transition to the intended item; reblur on motion/focus changes must not fade sharp text back into view.

**Separate blur strength from surface/tint opacity.** Setting the whole masking view to alpha 0.6–0.7 can blend 30–40% of the sharp original message into the result. That is a privacy regression, not the desired softer appearance. Keep the obscuring result complete; tune a tint over an already-blurred representation or otherwise prove that no unfiltered text contributes to the visible output.

For the synthetic lab, a genuine CIGaussianBlur variant can be evaluated by rasterizing/rendering its own invented content locally and filtering that representation. This does not require capturing another app or adding Screen Recording permission. Treat it as a separate visual candidate: generate a blurred base, handle filter edges/cropping correctly, and composite a proposed 60–70% tint over that blurred base without mixing in the sharp source. Test short text, high contrast, practical zoom, replies/media and both themes for unreadability and acceptable appearance.

This route only works with content the lab owns. It is not a way to obtain WhatsApp pixels under the existing no-capture budget. Do not copy it into external WhatsApp integration and claim those permissions/data-access problems are solved. Do not implement a new styling renderer before the hover bug is isolated and fixed unless it is clearly a separately reviewed visual prototype.

## Proposed task 5 — Verification and rollout gate

Run policy and actual hidden AppKit/controller/event integration regressions, both release builds, full project tests and signed capability/tamper tests. Preserve the existing no-network/no-capture/no-Accessibility budget. Update PR #5 with precise evidence and any fixture skips.

The user reports current click/scroll behavior passes on their setup; keep those regression cases in every hover recovery retest. Actual local event delivery, momentum and visual output still require user-operated testing on synthetic chats. Do not claim a source-only simulation reproduced the user's exact hardware sequence.

Production remains gated on consistent hover, accepted blur appearance and a viable external WhatsApp geometry/rendering architecture. This plan adds no permission grant, app installation, desktop-control authorization or production release.

## Primary references

Apple, NSEvent.phase and preparatory/legacy/momentum distinctions:
https://developer.apple.com/documentation/appkit/nsevent/phase-swift.property

Apple, trackpad event phases and cancelled/ended handling:
https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/EventOverview/HandlingTouchEvents/HandlingTouchEvents.html

Apple, alphaValue transparency:
https://developer.apple.com/documentation/appkit/nsview/alphavalue

Apple, CIGaussianBlur:
https://developer.apple.com/documentation/coreimage/cigaussianblur

Apple, materials and appearance:
https://developer.apple.com/documentation/appkit/nsvisualeffectview

# Click and scrolling exposure: investigation and fix plan

Initial status: source investigation and plan only. Implementation follow-up is recorded in [execution record](2026-11-04-click-scroll-execution.md). User reports the lab appearance matches the intended product, but clicking with hover reveal enabled briefly exposes every blurred item. Further user testing reports partial message exposure and visibly lagging blur patches during scrolling. No GUI reproduction, implementation, permission or installed-app changes were performed in this investigation.

## Severity and observed invariant

Treat this as a privacy correctness defect, not an acceptable demo animation. A click must not reveal unrelated messages or previews. During scrolling, blur must remain attached to each message/preview, move with its content, and clip at the same viewport edges; the user explicitly requires the feel of a native feature. A single intentional hovered region is the maximum allowed reveal. Passing the existing policy tests does not establish that WindowServer keeps the visual layers above the content.

User feedback is positive evidence for the general visual direction on their configuration. It is not blanket acceptance of every material, theme, system setting or display configuration, nor evidence that automatic native WhatsApp region discovery works.

## Evidence and ranked hypotheses

Reviewed current lab source and production renderer. No root cause is yet runtime-confirmed.

1. **Most likely: independent-window ordering race.** EffectWindow is a normal-level, click-through top-level NSWindow (main.swift:8–19). It is not attached as a child of the fixture window. Each refresh restores relative ordering (main.swift:178–185), at a 50 ms interval (108–109). Clicking through to the underlying key window may raise that window above all patch windows until polling repairs the order. This matches a simultaneous all-item flash. A click/stacking observation is still required to confirm it.
2. **Separate global-clear path: activation is coupled to rendering.** `ready = active && geometryReady` and `wanted = ready ? ids : []` (170–177) close every patch whenever activity is false. If activation changes during the triggering sequence, all masks are destroyed and reconstructed. The same path deliberately clears visible background content when the app loses focus. An event trace must distinguish this path from case 1; do not assume ordinary in-app clicks change NSApp.isActive.
3. **Possible compositor/material churn.** Every 50 ms, the code reapplies appearance/material/frame even if unchanged. This may cause unnecessary work; it is not yet established as the flash cause. Measure separately rather than declaring it the root cause.
4. **Intentional hover behavior is not sufficient to explain all-item exposure.** The reveal lease returns at most one ID and the render loop orders out only that ID. If all items disappear, investigate lifecycle/order/material paths rather than merely extending hover delays.

The production opaque renderer also uses independent normal-level windows and polling-based relative ordering (CoverOverlay.swift:11,47; PrivacyMonitor.swift timer 0.1 s). The reported demo flash is not proof of the exact same live defect there, but the architectural risk is shared. Do not promise this vanishes automatically in production.

## Additional findings — scrolling is a separate architecture defect

User-observed: as the conversation scrolls, portions of messages become readable and patches visibly catch up. This observation is distinct from the click-triggered simultaneous flash.

Source-confirmed mechanism:
- The text belongs to NSScrollView document views and moves when AppKit updates the clip view bounds.
- Blur belongs to independent top-level screen-positioned windows, not the document view hierarchy.
- Geometry is recomputed only in refresh(), driven by the 50 ms timer (nominally 20 updates/second). There are no clip-bounds/live-scroll observers or content-coupled transforms in the current renderer.
- screenRect() computes and clips a correct rectangle for the instant it runs. It cannot keep a separate patch aligned during the following scroll updates. Incoming/partially clipped rows are also discovered only at the next refresh; departed patches are removed then.
- Layout epoch changes are detected after this sampled geometry changes. Reveal invalidation therefore also waits for polling.
- The planner's timestamp check validates the supplied snapshot; setting observedAt/now during refresh does not synchronize WindowServer presentation of the text and patch windows or prevent exposure between refreshes.

This is sufficient to establish a structural synchronization weakness. The exact contribution of window stacking, material redraw and frame publication to each observed exposed frame still needs synthetic live observation. Do not label that compositor-level causality reproduced by source inspection alone.

Illustration only: at 600 points/second, 50 ms of separation corresponds to 30 points of movement—enough to uncover text lines. Real intervals depend on event scheduling and scroll velocity; these are not measured results. Faster timers or display-linked updates might reduce separation but do not establish atomic presentation between independent windows.

Required invariant: an unauthorized message and its blur must share a scroll transform, clipping and presentation lifecycle. Newly visible content must be blurred before its first displayed frame; a stationary pointer must not reveal a succession of messages that scroll underneath it. No fade-out/fade-in or global mask removal while scrolling. Names, headers and composer must remain usable and uncovered.

A parent/child NSWindow relationship may address click ordering and whole-window movement. **It does not make child windows scroll with document content.** The previous child-window proposal is therefore insufficient on its own for the combined defects.

## Task 1 — Reproduce and identify the failing layer

Use only the invented demo chats. The agent must not operate the user's desktop. Build optional in-memory synthetic-only diagnostics, then have the user run the reproduction; do not inspect or record real chats.

Reproduction matrix:
- Hover reveal off versus on.
- Click composer, a blurred message, an intentionally revealed message, an unrelated preview/name and blank background.
- Already-active window versus first click after switching applications.
- Rapid repeated clicks, text selection/drag, scroll then click, hover expiry then click.
- Slow/fast trackpad scroll, inertia after fingers leave, rapid reversals, mouse-wheel steps, scrollbar dragging, keyboard/programmatic scroll and rubber-band overscroll.
- Independently scroll the conversation and sidebar; exercise both at viewport edges with partially visible rows/messages and newly entering content. Use 1/10/30 rows and both text sizes.
- Scroll while a region is revealed and while the pointer stays stationary above moving content; repeat with hover disabled to isolate geometry from reveal logic.
- Repeat with each available material and in light/dark appearance.

Capture local non-content event state: relative sequence/time, trigger category, app/key-window activity, clip bounds/scroll phase, layout epoch, per-region content-space bounds and presented bounds, planned region count, active reveal ID, retained/visible patch count and the fixture/patch ordering. Use a bounded in-memory buffer cleared on quit, no file/network export, no message text or typed keys, no global input/event tap. Local fixture-window mouse/focus handling is sufficient. Diagnostic absence is not a pass.

Interpretation:
- Regions retained but ordered behind the fixture: ordering cause confirmed.
- Region count drops to zero during activation: lifecycle-clear cause confirmed.
- Patches remain correctly ordered/visible yet blur disappears: investigate NSVisualEffectView compositor invalidation separately.
- Content has moved but patch positions/clipping retain the preceding scroll state: sampled geometry/presentation lag confirmed.
- Incoming content appears before its mask exists: visibility/creation lifecycle gap confirmed.
- Hover off still exposes scrolling content: the renderer, not just the reveal lease, must change.

Do not fix by shortening the timer or claiming a higher polling frequency eliminates exposure.

## Task 2 — Stabilize the same-process lab renderer

Files: Experiments/SelectiveBlurLab/Sources/SelectiveBlurLab/main.swift; optionally extract a focused FixtureBlurRenderer.swift and presentation model for testability. Address click ordering and scroll synchronization together; do not close this work after fixing only the click flash.

For an external-window baseline, if ordering is confirmed: attach patch windows to the lab's own fixture NSWindow as ordered-above child windows using public AppKit APIs. Parent/child ordering should replace repeated attempts to repair independent z-order. Preserve non-key status, normal level and click-through input. Detach children deliberately before removal/close. Do not introduce always-on-top global windows.

Keep patch objects and ordering relationships stable during ordinary clicks and hover changes. Prefer changing only the selected effect's presentation while retaining its transparent host/parent relationship, rather than ordering the host out and reintroducing it. Verify selected-item hiding actually suppresses only that visual effect before adopting the exact mechanism. Unselected patches must not be detached, hidden, closed or reconstructed on an ordinary click.

Only update frame, appearance or material when that value changes. Geometry changes must update existing patches and cancel reveal without treating a redraw as permission to expose all content. Separate item removal from temporary focus changes.

### Task 2A — Make the synthetic blur participate in content scrolling

Preferred candidate for the lab's native-feel requirement: retain a blur view associated with each synthetic message/preview container in the same document hierarchy. Evaluate public NSVisualEffectView withinWindow blending, with the view above its intended content and sharing that container's bounds, scroll transform and ancestor clipping. Use separate non-overlapping effect regions, consistent with Apple's documented withinWindow limitation. Keep controls click-through by view hit testing. Do not alter message layout or cover names.

Create/reuse blur presentation with content, including offscreen items before they enter the viewport. The present finite synthetic documents allow creating all regions in advance. Any later virtualized implementation must initialize protection before displaying a recycled/new item. Move/clip content and blur through one layout/presentation path with implicit animations disabled for privacy-state changes. Do not independently animate a patch toward an already-moved message.

This is a renderer candidate to prove, not a verified fix: in-window materials can look different, so compare against the user-accepted demo appearance and reject any return to an opaque sheet or readable text. Do not assume subview placement alone guarantees a correct backdrop or unreadability.

Observe each fixture clip view's bounds/layout changes and live-scroll state for immediate reveal cancellation and layout bookkeeping. Bounds changes must be handled even when no start/end pair arrives: Apple's SDK notes that some legacy-mouse scrolls are not bracketed by live-scroll start/end notifications. Programmatic/keyboard movement must also invalidate reveal. Event-driven invalidation is required, but notifications posted after movement do not by themselves prove that separately positioned patch windows present atomically.

Cancel an active reveal when scrolling begins or bounds change. Keep every item blurred through scrolling/inertia and until an actual pointer exit/re-entry permits a new reveal. Do not reveal a newly arriving message merely because it now sits under the old pointer. No steady-state geometry timer should be needed to keep in-document blur aligned.

Keep an explicitly labelled external-window baseline if needed for comparison. The in-document renderer proves behavior only for content the lab owns. It does not validate external WhatsApp rendering, access WhatsApp's view hierarchy, or solve message-region discovery.

## Task 3 — Separate covering, focus and hover permissions

Refactor the presentation inputs conceptually into:
- `shouldRender`: fixture is visible/not minimized and geometry is usable.
- `canReveal`: shouldRender plus active/key fixture and trustworthy local pointer hit.

Losing focus cancels reveal and restores blur; it must not automatically expose still-visible fixture content. Parent-relative attachment should keep patches associated with the fixture behind other foreground windows, without floating over other apps. Minimize/close should remove/hide patches with their parent when the underlying target is no longer displayed.

Preserve the existing suspension latch: nil pointer input while inactive is not evidence of pointer exit. Regaining focus with a stationary pointer must not grant a new reveal lease. Clicking is not a new reveal authorization. A selected item's reveal must remain independent of unrelated patches.

Use fixture-window focus/visibility notifications for immediate lifecycle reconciliation rather than waiting for the polling tick. Polling can remain a fallback for geometry/hover; it is not the correctness mechanism for click ordering. Do not claim zero-frame secrecy merely because callbacks are synchronous.

## Task 4 — Add regression evidence at both policy and renderer boundaries

Write the failing regression before the fix, based on the confirmed reproduction.

Policy/presentation tests:
- Three or more blurred items, one allowed reveal: a click leaves every unrelated item blurred.
- An active click does not cause global removal/recreation or reset the reveal lease.
- Losing focus restores the revealed item while retaining blur for visible content.
- Focus regain/keyboard switching with stationary pointer cannot renew reveal.
- Pointer exit and expired leases reblur appropriately.
- Scroll start, every clip-bounds change, inertia and layout invalidation cancel reveal; a stationary pointer cannot acquire a fresh item.
- A burst of scroll positions faster than the former 50 ms timer keeps blur geometry tied to content transforms without invoking a geometry polling tick.
- Partially visible and newly entering messages/previews have correctly clipped protection; names/header/composer remain excluded.
- Retained item presentation is not globally removed/recreated on a scroll; recycled/new items cannot first appear unblurred.
- Legacy wheel, keyboard and programmatic movement are covered without depending on a live-scroll start/end notification pair.
- Minimize/close cleanup is distinct from key-window focus changes.

Actual AppKit integration acceptance, user-operated on synthetic data:
- Verify patch/parent relationships and ordering before, during and after clicks, not only at 50 ms snapshots.
- Check the same click and scroll reproduction matrix used to confirm the bugs. No observed unauthorized exposure, including partial message lines, is permitted in supported cases.
- Observe intermediate displayed frames during rapid scroll/reversal/inertia, not just settled positions. Pass requires blur moving as part of its message and clipping cleanly at both viewport edges, without patch trailing, blinking, name overlap or input interception.
- Compare the in-document candidate with the user-accepted blur appearance. Reject improved movement if it compromises unreadability or visual quality.
- Use synthetic-only high-frame-rate observation if needed; do not broaden the utility's capture permissions to test itself or ask for real-chat recordings.
- If logical state stays correct but pixels still flash, the defect is not fixed. Escalate to compositor/rendering design and keep production integration blocked.

Run ./scripts/test-blur-lab.sh, the existing project suite with both built artifact environment variables, both static signed builds and capability/tamper rejection tests. Source/unit/build success alone cannot close the visual regression.

## Task 5 — Reassess the production boundary explicitly

The fixture window is owned by this process, so AppKit can establish a parent/child relationship. Actual WhatsApp windows belong to another process; a CGWindowID is not an NSWindow object that we own. Do not assume that the lab child-window fix transfers to cross-process WhatsApp overlays or use private window-server APIs to force it.

Keep PR #5 draft and product integration gated until:
1. The synthetic click flash AND scroll-induced partial exposure are reproduced, corrected and visually retested.
2. The actual external-window rendering architecture is separately shown to retain synchronized per-message blur through scrolling/inertia as well as focus/click/occlusion transitions. An in-document demo fix does not satisfy this gate.
3. A reliable WhatsApp message-region provider exists under an explicitly approved capability budget.

The external WhatsApp integration cannot simply attach our NSViews to another process's document hierarchy through these public AppKit APIs. The requested native feel is an acceptance criterion, not justification for injection, private APIs or unapproved access. If a permitted external renderer cannot meet it, report that feasibility failure before production and revisit the architecture with the user.

No new screen capture, Accessibility, keyboard monitor, helper, network, elevated privileges, installation or OS setting changes are required for the proposed lab fix. Any broader alternative requires a separate capability decision. The user's acceptance of the blur appearance does not authorize those capabilities.

## References

Apple, addChildWindow(_:ordered:), ordered-above child relationship:
https://developer.apple.com/documentation/appkit/nswindow/addchildwindow(_:ordered:)

Apple, relative window ordering:
https://developer.apple.com/documentation/appkit/nswindow/order(_:relativeTo:)

SDK NSWindow.h confirms child/parent APIs operate on NSWindow objects. These references establish available mechanisms, not that the reported flash has already been reproduced or fixed.


Apple, clip-view bounds notifications:
https://developer.apple.com/documentation/appkit/nsview/postsboundschangednotifications

Apple, NSScrollView live-scroll lifecycle (SDK notes legacy input may lack start/end pairs):
https://developer.apple.com/documentation/appkit/nsscrollview

Apple, withinWindow blur; effect views using it must not overlap:
https://developer.apple.com/documentation/appkit/nsvisualeffectview/blendingmode-swift.enum/withinwindow

Initial update scope was documentation only. Subsequent user-authorized code changes and test results are recorded in the execution record; live visual acceptance remains pending.

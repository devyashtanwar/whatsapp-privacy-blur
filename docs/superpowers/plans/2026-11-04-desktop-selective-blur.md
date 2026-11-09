# WhatsApp Desktop Selective Blur Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Status:** Approved for execution. An access-only preview is being implemented on codex/desktop-blur-integration; see docs/research/2026-11-04-desktop-integration-execution.md. Live Gate A, message geometry and external overlay timing remain unverified. Unchecked tasks are not delivered features.

**Goal:** Deliver a user-selected-window native companion with independently configurable sidebar-preview, conversation-message, name and avatar Gaussian blur, subject to proven geometry and interaction privacy.

**Architecture:** Build a separate integration preview using the system window-sharing picker, authenticated window binding, bounded local frame processing and content-specific overlays. Reuse the accepted Gaussian algorithm and hover policy where their contracts apply; prove external geometry and timing before changing the existing production app. Keep capture, settings, detection, planning, rendering and status independently testable.

**Tech Stack:** Swift, AppKit, ScreenCaptureKit on macOS 15.2+ (exact picker scope inspection), Core Image, existing offline Security validation; standard-library Python build/verifier tooling. No external runtime dependency, OCR, Accessibility or model downloads.

**Spec:** [Desktop integration design](../specs/2026-11-04-desktop-selective-blur-design.md).

## Global constraints

- Explicitly selected single WhatsApp window only. Never silently fall back to display/app capture, blanket Screen Recording access, another target, or a private API.
- Preserve App Sandbox, hardened runtime, offline publisher checks and exact verified capability profiles. The existing cover and lab profiles remain unchanged during feasibility work.
- No networking, audio/microphone/camera/location, Accessibility, keyboard/clipboard monitoring, personal-file/database access, private-content logs, recording/export or persistent settings.
- Initial defaults after selection: sidebar-preview and conversation-message blur on; name and avatar blur off; both message hover controls off; tint 65% adjustable only within 40–90%. Fresh launch is idle, with no capture.
- Blur switches change rendered coverage; incoming frames can contain the entire selected window. Explain this in setup and Privacy Limits.
- Pause, all four blur categories off, stop and target/session loss stop capture and release app-owned references. No automatic target reattachment or capture at login.
- No full-window concealment fallback, no sharp-source blending, no protected status on uncertain geometry/stream health. Capture/render failure can expose original WhatsApp content and must say so.
- Agent performs CLI builds/tests only. User operates the visible picker/WhatsApp, grants access, and tests the preview. Do not install, launch, merge or replace an app automatically.

## Review focus

1. Picker changes to another window/display or reused PID/window ID: reject before rendering; no inherited session or reveal.
2. Sidebar row reorder, media/reply/RTL layouts and partially clipped content: no unrequested identity blur or gaps in requested message/name/avatar coverage under a supported status.
3. Dropped/reordered/frozen frames during momentum and chat changes: never reuse unrelated pixels, geometry or reveal identity.
4. Category off/on, pause/resume and stationary pointer: preserve all other enabled categories, require fresh reveal intent and stop capture when no work is enabled.
5. Occlusion, scale/Spaces/full-screen changes, process crash and system permission changes: report actual support/coverage state; never imply overlays make capture sharing or app crashes private.

## Delivery boundaries and file map

First create a separate `Experiments/DesktopIntegration/` preview, bundle ID `devyashtanwar.whatsapp-blur-preview`, not a replacement for WhatsApp or the installed cover. Reuse existing process-authentication source bytes through the immutable build snapshot rather than maintaining a weaker duplicate implementation. A staged Swift package can compile copies of the existing PrivacyCore and process identity adapter; the preview build records their hashes. All generated inputs stay under `.build/`, never synced project `sources/`.

Planned modules/files:

- `Experiments/DesktopIntegration/Sources/IntegrationCore/`: settings, capture-session state, frame/region contracts, plan validation and reveal state; no pixel persistence or AppKit UI.
- `Experiments/DesktopIntegration/Sources/DesktopBlurPreview/`: `SelectedWindowCapture.swift`, `StructuralRegionDetector.swift`, `GaussianOverlayRenderer.swift`, `IntegrationCoordinator.swift`, `SettingsPopover.swift`, `main.swift`.
- `Experiments/DesktopIntegration/Security/CapabilityPolicy.json`: explicit preview-only capture budget, separate identity, all other prohibitions retained.
- `Experiments/DesktopIntegration/Package.swift`: snapshot package template with existing authenticated identity inputs compiled alongside the preview.
- `Experiments/DesktopIntegration/Tests/`: pure session/settings/region/frame-order tests; hidden renderer/adapter tests.
- `scripts/build-desktop-preview.py`, `scripts/build-desktop-preview.sh`, `scripts/test-desktop-preview.sh`, `scripts/verify_desktop_preview.py`; `Tests/InstallerTests/test_desktop_preview_artifact.py`.
- `Experiments/DesktopIntegration/README.md` and `docs/research/2026-11-04-desktop-integration-execution.md`: exact access, gates, evidence and user test instructions.

Do not copy lab fixture text drawing into production. Keep `GaussianRenderer.swift` algorithm reuse auditable by using the same source bytes in the preview snapshot; keep lab-only GaussianMessageView and fixture adapters out of the preview target. Separate the filter into its own file as part of Task 1, preserving lab tests.

### Task 1: Isolated preview capability and settings contracts

**Files:** preview package/core/policy/tests, Gaussian filter extraction, build/test/verifier scripts and artifact tests above. Existing app and lab policies must not change.

**Interfaces:** `BlurSettings(sidebarPreviews: Bool, conversationMessages: Bool, names: Bool, avatars: Bool, sidebarHover: Bool, conversationHover: Bool, tint: Double)`; `needsCapture: Bool`; category enum `sidebarPreview`, `conversationMessage`, `contactName`, `avatar`. `SessionState` distinguishes idle, selecting, awaitingFrames, analyzing, active, paused, unsupported and failed. Store everything in memory.

- [x] Write failing settings/state tests: all 16 blur-switch combinations; names-only/avatars-only still require capture; hover ineffective for disabled message category and never effective for identity categories; tint clamps below 0.40 to 0.40 and above 0.90 to 0.90, accepts endpoints and 0.65, and resets nonfinite input to 0.65; fresh session defaults; no capture while idle/paused/all-four-off; reenable starts blurred.
- [x] Run the preview core tests and observe the expected behavior failures before implementation.
- [x] Implement core settings/state and the separately signed preview build. Copy existing identity inputs into the fixed snapshot, record provenance and reject unexpected entitlements, resources, helpers and forbidden APIs.
- [x] Add negative signed-artifact tests for network/audio/Accessibility grants, modified policy/resources, wrong identity and bypassed runtime gate. Confirm the preview cannot accept the cover/lab identity and vice versa.
- [x] Run new core/artifact tests, existing lab tests, `./scripts/test.sh`, `./scripts/build-blur-lab.sh` and `./build-app.sh`. Verify new capture allowances have not weakened the old audits.
- [x] Commit the independently testable preview boundary and filter extraction.

### Task 2: Explicit single-window selection and bounded capture

**Files:** `SelectedWindowCapture.swift`, `IntegrationCoordinator.swift`, core `CaptureSession.swift`, core `FrameSnapshot.swift`, adapter/session tests and execution record.

**Interfaces:** `startSelection()` is user initiated; `stop(reason:)` invalidates the session generation and pending work. A frame snapshot carries session generation, authenticated process generation/window ID, sequence, capture time, pixel dimensions, scale/transform and an in-memory image handle. Stale callbacks cannot revive a stopped session. Pixel handles never appear in diagnostics or persistence interfaces.

- [ ] Write failing mock-adapter tests for wrong publisher/target, display/app/multiwindow or unknown picker scope, cancellation, changed selection, late callbacks after stop, identity/window reuse, stream error, frozen stream and disabled audio. Assert no valid frame or active status escapes.
- [ ] Implement picker-only single-window capture and prove metadata supports authenticated exact-window binding. Reject unprovable scope; never expand capture to recover missing metadata. Bound input to one current and one pending frame, replacing pending work with newer input.
- [ ] Test pause, all-four-off, stop, target exit, capture revocation, session loss and resume. Assert app-owned frame references and reveals are released, work stops, and no automatic reselection occurs. Use lifecycle spies; do not call reference release forensic zeroization.
- [ ] Verify sandbox compatibility, system permission/consent behavior and no audio path in the signed preview. Agent runs mock/hidden checks; user tests picker with a harmless external fixture window and then a harmless WhatsApp window. No raw frames are saved or uploaded.
- [ ] Record pass/fail evidence. **Gate A:** exact selected-window authentication and scoped capture must pass before accepting any real-target processing. If picker identity binding or narrow consent fails, stop and report the gap.
- [ ] Commit capture lifecycle only after automated verification. An incomplete Gate A remains explicitly unsupported, not a production feature.

### Task 3: Real-window region feasibility and frame consistency

**Files:** `StructuralRegionDetector.swift`, core `RegionSnapshot.swift`, core `RegionValidator.swift`, external synthetic fixture scenarios/tests and execution record.

**Interfaces:** `detect(frame:) -> DetectionResult`, producing regions of `{id, category, bounds}` plus exclusion regions and supported/unsupported result, all bound to that exact frame/session generation. IDs are ephemeral and non-content-bearing. `validate(snapshot:settings:now:) -> RegionPlan` rejects mismatches, invalid transforms, unknown layouts and stale data. Do not relabel lab `.instrumentedFixture` evidence as external proof.

- [ ] Write fixture tests with separately annotated message, contact/group name, avatar and always-excluded control areas, including sidebar and conversation-header identity. Cover 1/10/30 rows, multiline/RTL/emoji/link previews, partial rows, reordering/new arrivals, actual message/media/reply layouts, light/dark themes and resizing. Assert complete requested-category coverage and no overlap with exclusions on every supported frame.
- [ ] Write failing contract tests for reordered sequences, cross-session images, changed dimensions/scales, unknown layout, duplicated IDs, invalid bounds and uncertain item correspondence. Assert no protected plan or inherited reveal.
- [ ] Implement structural image analysis only. Do not add OCR/string extraction or use a fixed row grid as automatic detection. Reject unsupported templates rather than guessing. Determine supported WhatsApp/macOS versions with user-operated harmless chats.
- [ ] Keep old geometry/pixels inseparable; discard superseded detection results. Establish and record measured frame-age/work/memory limits on the preview, and test the boundaries. The lab's 250 ms fixture limit is not automatically an acceptable external privacy limit.
- [ ] **Gate B:** publish a support matrix and observed coverage errors without private frames/content. If structural detection cannot reliably distinguish requested previews/messages/names/avatars from disabled categories and controls, stop: capture alone has not solved the requested feature. Do not proceed to general production blur or quietly add OCR/Accessibility.
- [ ] Commit the detector, negative cases and evidence; unsupported layouts remain unsupported.

### Task 4: Gaussian overlays, independent categories and external hover

**Files:** `GaussianOverlayRenderer.swift`, core `SelectiveBlurPlanner.swift`, core `RegionRevealController.swift`, `IntegrationCoordinator.swift`, core/hidden renderer tests.

**Interfaces:** planner consumes a single validated frame/region snapshot plus settings and current target state; returns category-specific localized masks and at most one revealed item for the active window. Renderer atomically replaces one generation with another. Reveal is bound to item identity and generation, not rectangle overlap.

- [ ] Write failing tests for all 16 blur combinations, including the four message modes, names-only and avatars-only; disabling one category removes only its masks and revokes its reveal. Enabled name/avatar masks must remain blurred throughout message/preview hover, even when identity and message bounds touch. Names and avatars have no hover-reveal setting in this version. Reenabling cannot produce a sharp first frame. Test unsupported one-category geometry without claiming the other is also protected.
- [ ] Implement opaque flattened crops -> Gaussian -> tint, using the accepted filter algorithm. Preserve exact scale and message edges; compare 40/65/90% tint, themes, text/avatar boundaries and readability; all images remain opaque and contain only blurred source beneath the tint, including at 40%. Verify alpha/pixel edges and opaque filter-failure handling in memory. Never show raw input frames in a debug overlay.
- [ ] Implement click-through non-key overlays and cursor/window-metadata hover, without global event taps, keyboard monitoring or Accessibility. Require actual pointer displacement on a current topmost supported item; timer/frame arrival alone cannot reveal. Start with a two-second lease and 150 ms settled period; invalidate on observed motion/layout/focus/category changes.
- [ ] Add regression sequences for delayed pointer inputs, stationary pointers while content moves, missing end events, momentum, chat switches, transient overlapping rectangles and frame-order changes. Direct post-scroll hover must recover without window switching or sampling empty space.
- [ ] Run hidden tests, then user-operated external fixture and WhatsApp acceptance. Measure alignment delay and inspect rapid clicks/scroll/momentum for visible disclosure. **Gate C:** reject a release candidate if the external overlay loses privacy while scrolling or cannot match the accepted UX. Document asynchronous limitations; do not claim pre-scroll revocation or zero-frame protection.
- [ ] Commit the verified renderer/controller and explicit failures. No production promotion while Gate B or C is incomplete.

### Task 5: Native settings and honest protection status

**Files:** `SettingsPopover.swift`, `IntegrationCoordinator.swift`, status/core tests, preview README and execution record.

**Interfaces:** UI edits session-only BlurSettings, invokes explicit selection/pause/resume/stop, and consumes category-specific status. Protected/active status requires current target, running stream, supported valid geometry and successful rendering for every enabled category.

- [ ] Write failing state/UI-binding tests for all 16 blur combinations, independent message hover controls, identity masks remaining blurred during hover, all-four-off stream stop, disabled-category hover, pause/resume, changed selection, permission loss and partial unsupported coverage. Status must identify which requested category is unsupported and must never report full protection for partial coverage.
- [ ] Build the compact native menu-bar popover defined in the design: selected window, Messages and Identity sections with four independent blur switches, the two message hover controls, shared 40–90% tint initially at 65%, pause/resume, stop and privacy limits. No whole-window reveal control, synthetic-fixture settings or silent emergency cover.
- [ ] Disclose full selected-window pixel access even in sidebar-only mode, session-only settings, failure exposure, screenshot/share limitations and no background capture at launch/login. Update obsolete claims such as “no screenshots needed” only in the new integration product's documentation/UI.
- [ ] User verifies readability, keyboard/menu usability, click/scroll/type behavior, message-edge appearance and the two requested message-only modes, names-only/avatars-only modes and identity blur combined with message hover. No agent-operated GUI.
- [ ] Commit accepted UX and documentation with supported/unsupported states backed by tests.

### Task 6: Review, rollout and production promotion

**Files:** `.github/workflows/verify.yml`, preview artifact tests, support/test documentation; only after all gates, root production integration files `Package.swift`, `Sources/HideWhatsApp/{PrivacyMonitor,StatusBar,Settings,CoverOverlay}.swift`, `Sources/PrivacyCore/`, `Security/CapabilityPolicy.json`, build/verifier tests and `SECURITY.md`.

- [ ] Add a separate preview CI job running tests, immutable build and signed-artifact rejection tests without launching GUI or granting permissions. Keep existing cover/lab jobs.
- [ ] Run all existing/new suites and inspect actual entitlements, linked APIs and offline trust behavior. Review capture lifetime, memory retention, runtime-policy integrity and absence of content/network/persistence paths independently.
- [ ] Deliver a clearly named preview build and PR, with Gate A/B/C evidence and user instructions. Test ordinary foreground windows first; full screen, Spaces, occlusion, multiple displays and modals are unsupported until verified. A failed gate is a documented stop, not permission to broaden access.
- [ ] After user acceptance and passed gates, transfer tested modules into the production target in a separate reviewable commit/PR. Replace broad cover configuration with category settings, preserve identity checks and carry the reviewed capture capability profile into startup/build verification. Remove obsolete cover assumptions from UI/docs/tests; do not weaken unrelated negative checks.
- [ ] Rebuild/reverify production artifact and rerun all category, lifecycle, security and regression tests. User explicitly installs/tests the reviewed artifact. Do not merge or install automatically.

## Planning review and current evidence

The original design received an independent macOS/privacy builder review with no important unanswered questions; feasibility uncertainties remain explicit gates. The later user amendment widens tint to 40–90% (initially 65%) and adds optional name/avatar blur. Self-review updated the contracts, all 16 category combinations, capture lifetime, geometry exclusions, hover isolation and rendering checks for that amendment. The prior independent review is not claimed to cover the amendment. No implementation/tests/builds were performed for this documentation update. Prior lab results are regression references, not evidence that real-window integration works.

User approved execution. That authorizes Task 1 onward within this scope, not bypassing Gate A/B/C or adding OCR, Accessibility, broad capture or other privileges after a failed experiment.

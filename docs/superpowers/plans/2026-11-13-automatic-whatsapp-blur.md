# Automatic WhatsApp Blur Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Status:** User approved execution on 2026-11-13. Work is on codex/automatic-whatsapp-blur; runtime capability/visibility/performance acceptance remains unverified.

**Execution record:** [implemented components, test evidence, review fixes and blocked live/performance gates](../../research/2026-11-13-automatic-beta-execution.md). Internal implementation is available for draft review; Task 2 live acceptance, Task 3 permission retention and Task 5 native performance/coverage acceptance remain open. No production promotion.

**Goal:** Automatically discover/authenticate/attach to supported native WhatsApp windows when enabled, without repeated picking, with truthful current rendering and measured performance.

**Architecture:** Separate permission/preferences, process/window discovery, lifecycle control, bound capture, region analysis and presentation. Evolve the DesktopIntegration beta under a new explicit automatic permission profile. Keep source/geometry/reveal binding and existing offline confinement; prove external visibility and latency before production promotion.

**Tech Stack:** Swift5.9+, AppKit, public ScreenCaptureKit/CoreGraphics, on-device Vision, Core Image; macOS15.2+; standard-library Python build/security tooling; no external runtime dependencies.

**Spec:** ../specs/2026-11-13-automatic-whatsapp-blur-design.md

## Global constraints

- Screen Recording permission is broader than WhatsApp; code captures only offline-authenticated net.whatsapp.WhatsApp windows through desktopIndependentWindow filters. No display/app-wide filter or other-app pixel fallback.
- Persist only validated non-content blur preferences in the app container. No messages/OCR/images/titles/target identifiers/history/diagnostic files. No network/telemetry, audio/mic/camera/location, Accessibility, key/clipboard monitoring, user-file/database access, private APIs or helper.
- Preserve sandbox/hardened runtime/offline checks. New automatic beta ID devyashtanwar.whatsapp-blur-auto-beta; root cover/lab budgets unchanged. No OS-grant automation, install, app launch or merge by the agent.
- Tint40–90%, default65%; message categories on, identity/hover off; persisted Pause must prevent automatic restart. Settings-close hides UI; Quit preserves preference for next explicit launch.
- No protected status, zero-first-frame promise, full-pane fallback or stale/mismatched reveal. Failed/withdrawn overlays expose original content.
- User live acceptance is mandatory; all synthetic success is limited evidence. No new working-build claim before the integrated pipeline and live feasibility gates.

## Review focus

1. Picker callback never arrives, permission denied/revoked, stale callbacks: bounded state, recoverable action, no endless spinner or repeated permission requests.
2. Either app launch order, delayed/new windows, process restart/PID-window reuse: exact fresh authentication and no old pixels/reveal inheritance.
3. Wispr/settings/another app frontmost and partial occlusion: exposed WhatsApp stays blurred without drawing its content above unrelated windows.
4. Corrupt preferences, explicit Pause, all-off, wake/lock/session changes: persisted intent honoured, bounded retries, immediate stop/reference invalidation.
5. Cold OCR/GPU, high-DPI scrolling and multiple windows: measured age/resource limits, no stale controls or sharp fragments disguised by a fast counter.

### Task 1: Establish startup observability and integrated regression harness

**Files:** modify Sources/CaptureAdapter/SelectedWindowCapture.swift, Sources/IntegrationCore/{CaptureSession,PickerEventPolicy}.swift and Tests/main.swift; create Sources/IntegrationCore/StartupTrace.swift, IntegrationHarness/main.swift inside Experiments/DesktopIntegration; update its Package.swift, scripts/desktop_preview.py and corresponding manifest-pin tests.

**Interfaces:** StartupTrace records at most32 in-memory enum stage/rejection/time entries, no target/content strings. Harness uses the real lifecycle/coordinator/decoder/detector/compositor behind injected permission/workspace/catalog/stream/presentation boundaries; production composition always constructs real offline identity validation, never a test bypass.

- [ ] Write regressions: selection request with no callback reaches recoverable timeout30s; cancellation/rejection/stale callback/late acceptance cannot revive old state; identify every boundary from request through actual surface publication. Add synthetic CMSampleBuffer attachment/valid-ready-image cases through the actual receiver, not just enum checks.
- [ ] Run ./scripts/test-desktop-preview.sh and observe the new failures. Implement the bounded pending-selection watchdog and RAM-only stage trace; expose useful last stage/build ID in diagnostics, not chat data.
- [ ] Wire an invented three-pane source through the real integrated pipeline and assert localized pixels appear, actual installed-image status is required, no requested detected category never displays raw input, and settings/picker focus does not lose first-frame preparation. No visible app or real capture in agent tests.
- [ ] Run the integrated tests and existing suites. Commit this independently diagnosable baseline. Actual missing-callback cause remains unproven unless observed; do not equate timeout handling with fixing macOS delivery.

### Task 2: Prove background/partial-occlusion presentation before automatic rollout

**Files:** create Sources/IntegrationCore/VisibleRegionPolicy.swift and Sources/DesktopBlurPreview/TargetPresentation.swift; modify IntegrationCoordinator.swift, NativeRendering/FrameCompositor.swift, hidden renderer/harness tests; create a separate VisibilityFixture package with renderer-only WindowOwner/main.swift and VisibilityHarness/main.swift for user-operated invented-content ordering tests. Its modules/resources/identity bypasses must not enter the beta graph.

**Interfaces:** VisibleRegionPolicy.exposed(target: CGRect, occluders: [CGRect]) -> [CGRect]; TargetPresentation consumes validated frame/regions plus exposed rectangles and returns actual display outcome. Hover eligibility remains current exposed item plus active WhatsApp; background blur is independent of foreground.

- [ ] Write failing tests: other app/settings active with target unobscured still blurred; settings covering body leaves sidebar blur; full occlusion hides surface; no paint in occluders; lost visibility revokes leases and queued reveal; rapid focus/order changes never borrow old context.
- [ ] Implement metadata-based visible regions and public normal-level relative ordering; remove global normal+1/foreground-only assumptions. Preserve generation/ownership/bounds checks immediately before presentation. Do not access another app's NSWindow object or private APIs.
- [ ] Run hidden mask/order-policy tests, then user-operated external fixture acceptance. Specifically test cross-process public ordering, drag/partial overlap, settings-close, fullscreen/Spaces/displays and click-through target correspondence.
- [ ] **Gate:** if actual ordering or coherent mirror lag cannot meet safe usable presentation, stop promotion and report evidence; no guessed global-topmost workaround. Commit proven policy/components with unsupported modes explicit.

### Task 3: Add reviewed automatic permission and non-content preference boundary

**Files:** create CaptureAdapter/ScreenPermission.swift, IntegrationCore/AutoPreferences.swift and DesktopBlurPreview/PreferenceStore.swift; revise Security/CapabilityPolicy.json, IntegrationCore/PreviewPolicy.swift, RuntimeConfinement.swift, Package.swift, scripts/desktop_preview.py and Tests/InstallerTests/test_desktop_preview*.py; update exact reviewed bootstrap/manifest pins after review.

**Interfaces:** ScreenPermission.preflight() -> granted/required/unavailable; request only on explicit first-setup action. AutoPreferences has schemaVersion, automaticEnabled, existing BlurSettings only. PreferenceStore.load/save use one fixed private-container location; corrupt data returns a visible error and disables automatic capture.

- [ ] Write failing cases: first grant/denial/revocation, no repeated prompting, corrupt/unknown keys/nonfinite tint, paused preference across restart, atomic write failure and redirected path. Assert no identifiers/content/history accepted by the schema.
- [ ] Implement first setup and the new explicitly described automatic profile. Allow SCShareableContent and permission calls only in reviewed adapters; retain negative checks for display/app-wide filter construction, unrelated usage descriptions, network/mic/Accessibility/user-file grants, content export and external dependencies. Add only a required screen-capture usage description if current SDK/OS requires it.
- [ ] Choose a stable bundle ID/path and documented signing workflow. Verify permission retention across a rebuild/update; do not promise permanent or exactly-one-time authorization, silently generate certificates or weaken signature checks. User grants permission; agent never does.
- [ ] Run profile/schema and re-signed artifact rejection tests; inspect actual entitlements/frameworks. Commit security/persistence boundary separately; root/lab remain unchanged.

### Task 4: Implement automatic authenticated discovery and lifecycle

**Files:** create IntegrationCore/AutomaticAttachment.swift, CaptureAdapter/{WhatsAppDiscovery,AutomaticWindowCapture}.swift and related core/harness tests; adapt current selected-window capture into shared bound-stream handling without requiring a picker in normal mode.

**Interfaces:** CaptureTarget = windowID/PID/processGeneration; discovery retains SCWindow handles privately, returns only authenticated targets. AutomaticAttachment.reduce(event,now) -> effects defines Disabled/NeedsPermission/WaitingForWhatsApp/Discovering/Authenticating/Starting/Analyzing/Rendering/Partial/Unsupported/Recovering/Error. AutomaticWindowCapture.start(target,session) resolves and rechecks ownership/generation before a single-window filter; stop(reason) invalidates callbacks/results.

- [ ] Write failing launch-order matrix: blur starts first, WhatsApp starts first, delayed window, second supported window, exit/relaunch/reused IDs, untrusted same bundle ID, denied/revoked permission, Pause/all-off/settings-close/quit/wake. Persisted Disabled never starts; no title-based target selection.
- [ ] Implement startup runningApplications scan and correct NSWorkspace notification-center registration, reconciled with runningApplications for missed/background launches. Coalesce100ms; delayed-window retries100/250/500ms then<=1Hz while trusted app exists; no content-catalog polling with WhatsApp absent.
- [ ] Build exact independent-window filters only; inspect count/owners before frames. No cached IDs persisted. Bounded transient stream retry250/500/1000ms; security/permission/explicit pause never uses that retry path. Implement aggregate pixel/stream resource limit before concurrent contexts; test two ordinary windows and honest partial state on exhaustion.
- [ ] On move/resize/scale/session change, revoke transforms/reveal, reconfigure/reconcile automatically under existing permission, and accept only fresh correctly bound frames. Never silently retain mismatched masks or require the picker to recover ordinary lifecycle events.
- [ ] Run integrated event sequences through real coordinator/render components and all identity/stop/start/reuse regressions; commit automatic attachment. No live success claim yet.

### Task 5: Measure and fix the real processing/presentation bottlenecks

**Files:** modify CaptureAdapter frame processing, GeometryAnalysis/NativeLayoutDetector.swift, NativeRendering/FrameCompositor.swift and shared GaussianFilter source/snapshot mapping only as needed; add bounded in-memory pipeline metrics and generated performance scenarios.

**Interfaces:** metrics contain stage durations, image age, drops and own memory only. One current/newest pending frame per context plus an explicit measured global budget; no unbounded task queues. Frame attachment contentRect/contentScale/scaleFactor must participate in exact pixel-to-window transform binding.

- [ ] Add failures for nonzero contentRect/letterboxing/Retina scales, out-of-order completion, cold first analysis, huge windows, two-window contention and incorrect source/geometry pairing. Use actual synthetic frame attachments and hidden pixel assertions.
- [ ] Profile capture/authentication/copy/OCR/Gaussian/presentation separately. Move heavy work off main, reuse a hardware Core Image context with tested opaque Gaussian semantics, and bound/cancel superseded work. Preserve strict offline trust; no speculative authentication relaxation. Reuse geometry only where current-frame evidence proves validity, never to conceal an unmet scroll deadline.
- [ ] Benchmark proposed gates: detect after notification<=250ms; first processed image<=1s after eligible window/permission; changing-content age p95<=100ms and no displayed changing frame>250ms, target30fps. Record cold/warm timings and actual CPU/pixel/GPU resource budgets at normal/Retina sizes. Targets are acceptance proposals, not prior evidence.
- [ ] User tests harmless native text/media/RTL/replies/clipped rows, scroll/momentum/clicks, hover recovery and settings against the same build. No readable fragments, stale click targets or unsupported category hidden under an active status. If OCR/mirror architecture fails, stop production promotion instead of shipping isolated-test success.

### Task 6: Make automatic mode the product flow and deliver one reviewable candidate

**Files:** PreviewApp.swift, IntegrationCoordinator.swift, settings/presentation helpers, README/security docs, build/verification scripts, .github/workflows/verify.yml and support/acceptance record.

**Interfaces:** launch loads preferences and starts the automatic controller without activation/settings popup. Closing settings only hides UI. Pause persists disabled and stops; Resume reauthenticates; Quit stops without clearing saved Enabled. Main UI exposes meaningful actual lifecycle/partial/error state and retains all existing blur/hover/tint controls.

- [ ] Add failing UI-binding/harness cases for both launch orders, saved preferences, close-settings continuity, denied permission, no WhatsApp, reconnection and actual surface vs stream-only state. Ensure no Choose action is required in normal mode.
- [ ] Implement the native menu-bar flow and one-time setup instructions; expose build/mode in About/diagnostics to distinguish stale running binaries. Keep first-paint/crash/withdrawal/permission/latency limits clear and no always-secured label. No login item added by default.
- [ ] Run ./scripts/test-desktop-preview.sh, signed automatic-beta build/negative checks, ./scripts/test.sh, legacy cover/lab checks and all hosted jobs. Fresh whole-branch security/behaviour review; address Important findings with regression tests.
- [ ] Deliver a draft PR/candidate only after internal integration and feasibility gates; user installs/grants/tests manually. Acceptance must cover both app start orders, WhatsApp restart, settings close, background/partial overlap, new windows, permission loss, settings persistence and measured native smoothness. No agent GUI/installation/merge or unsupported production promotion.

## Self-review / handoff

All requested automatic lifecycle cases are assigned; permission and persistence choices are explicit. Foreground/occlusion mismatch and picker pending-state defect are treated separately. Presentation feasibility precedes automatic rollout, and automatic lifecycle does not substitute for real geometry/performance evidence. Existing inline execution preference is preserved. No runtime code or OS permission is changed by writing this plan. Execution was approved; see the execution record for implemented work and outstanding acceptance gates.

Builder check: no important unanswered planning questions. Engineering fixture-isolation choice is explicit in the design. That statement applied to the planning commit. Runtime changes now exist; first-paint guarantees and native acceptance are still not inferred from generated assertions.

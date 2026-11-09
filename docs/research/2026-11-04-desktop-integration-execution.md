# Desktop integration execution record

Base: 804f054. Branch: codex/desktop-blur-integration. User approved implementation of the updated design with four categories and 40–90% tint (65% initial).

Ruling: Reuse the existing agent-owned checkout on a dedicated branch rather than creating another worktree. No desktop, installed app, OS setting or permission was operated.

Ruling: The integration preview requires macOS 15.2, not the proposed 14.0 minimum. The SDK and Apple documentation place SCContentFilter.includedWindows/includedApplications/includedDisplays at 15.2. Those APIs are needed to bind a picker selection to the exact authenticated process/window without broad content enumeration. Cost: older systems cannot run the preview; existing cover/lab remain unchanged.

Evidence: settings scaffold failed 86 of 138 assertions; implementation passed all 138. Capture-session scaffold failed 12 of 169 assertions, including restart after stop and accepting malformed/stale input. Runtime-policy scaffold rejected the valid profile, proving the positive path needs implementation. Logs are local scratch under /private/tmp/desktop-*-red.log, not private content.

No real-window capture has been performed by the agent. Gate A live consent/selection compatibility, Gate B real-message geometry and Gate C external scroll/privacy remain unverified. No protected status or production promotion is authorized by compile/unit tests alone.


Ruling: Deliver the first integration checkpoint rather than promote unproven overlays. It accepts one complete frame for metadata validation and immediately stops, discarding later callbacks. Task 2 is partial until user-operated Gate A succeeds; real-message detection and Gaussian overlays (Tasks 3–5) are not implemented. Cost: this is not yet usable to hide real messages. This follows the approved stop gates, not a claim of completed production integration.

Ruling: Retain the original validated system-issued filter rather than construct a replacement filter from its SCWindow. This preserves the picker's consent path while exact window/display/app scope is checked. Cost: picker behavior must still be confirmed on the target OS; there is no broader fallback.

Ruling: The signed preview accepts only authenticated WhatsApp, so it cannot capture a synthetic fixture app for the live selection test. Use synthetic descriptors and actual configuration-object tests without capture, then user-selected harmless WhatsApp for Gate A. Cost: external synthetic capture is not covered; no fake identity exception is introduced.

Implementation: four-category/tint settings and exact signed-policy runtime gate; session/epoch validation; one new observer per picker request so delayed callbacks retain their original token; existing offline target validation compiled from fixed source bytes; exact selected-window ownership recheck via single-window metadata; audio/mic off; 4096×4096 maximum frame size; queue depth two; 15-second no-valid-frame watchdog; session/sleep/target-loss stop; distinct native preview UI with explicit unprotected status. No pixel image retention/render/export path. The existing Gaussian algorithm was extracted unchanged from invented-text drawing for later reuse, with lab regressions retained.

Additional RED evidence: actual configuration defaults failed 9/10 assertions (unbounded/incorrect dimensions, cursor/queue policy); implemented configuration passes. Picker scope scaffold failed 2/189 assertions; valid scope and rejection cases are included in the final run. Python source-policy scaffold failed 18 negative cases; source/dependency/offline/capability checks now pass. These tests do not prove live picker/stream operation.


## 2026-11-09 review and fix pass

The same independent review resumed after a service usage limit interrupted it. It requested changes before access-checkpoint delivery: (1) unexpected same-request picker updates were ignored after initial selection, (2) bootstrap-guard removal passed audits, (3) repeated stop could publish completion too early, plus a lifecycle ordering concern. No critical issue was established. No real picker or stream behavior was certified.

Fix pass: picker event policy now distinguishes stale requests from unexpected current-session changes and invalidates frame acceptance on the latter. A pure lifecycle reducer serializes start/stop acknowledgements, keeps selection blocked until release, preserves stopping status on repeated requests and terminates the preview if shutdown is unconfirmed after five seconds or errors. Old callbacks cannot mutate the next stream. No unhandled second asynchronous stop is issued. Tests cover delayed/duplicate/reordered callbacks, errors and timeout without creating any stream.

Startup enforcement now separates a tiny main bootstrap from UI construction and pins the reviewed bootstrap, confinement validation and compiled capability-policy source hashes. The build rejects removal/alteration before compilation; the bundle verifier checks the sealed provenance pins and required Security imports. Signed-artifact tests replace the binary with a non-validating executable and change the bootstrap provenance. Neither executable is run. This is regression enforcement, not proof against an attacker who can modify the builder, pins and binary together.

RED evidence from this pass: unexpected active-session picker update produced one assertion failure; the initial lifecycle scaffold produced additional failures in the 209-assertion suite; startup bypass mutations produced four Python subtest failures. Implemented reducers and bootstrap checks pass the local focused tests; final full-suite/build results are appended after verification.

Final: minor (deferred): snapshot records HEAD after copying inputs without the existing cover builder's before/after revision check. Per-input hashes describe the compiled bytes, but a concurrent checkout change could mislabel baseRevision. Avoid checkout changes during preview builds; this remains visible in the PR rather than being called fixed.

Final: Ruling: live picker consent/filter metadata, exact-window continuity under window-ID reuse, macOS capture/stop indicators and revocation, lock/Spaces/full-screen/occlusion, real-message geometry and all external rendering/scroll/hover/readability remain unverified. Only the user-operated access checkpoint may be tested next; no production privacy claim follows. Cost: the user's requested real-message blur is still not delivered.


Final verification (2026-11-09): 209 integration core assertions and 10 actual ScreenCaptureKit configuration assertions pass; 74 Python repository tests pass with three explicit authentic-fixture/live-process skips; existing core checks pass (14 checks/77 assertions) and lab regressions pass (35 policy/131 hidden-view assertions). All three built bundles pass capability/signature/artifact checks; the reviewed preview's signed source manifest matches current input hashes. The corrected bootstrap-gate binary fixture copies bytes without inheriting protected system-file flags; an initial copy2 fixture failed on macOS chflags, not application behavior. Python syntax was checked without writing outside the workspace after the default Python cache path was denied. No app/picker/stream was launched by these tests.

Final: fixed unexpected picker updates — synthetic active/stale request regression RED→GREEN; current-session updates stop access and old requests remain ignored.
Final: fixed premature repeated-stop status and lifecycle uncertainty — deterministic start/stop reducer RED→GREEN; selection remains blocked until confirmed release; timed-out/failed shutdown terminates the preview.
Final: fixed missing bootstrap enforcement — four bypass mutations RED→GREEN; reviewed bootstrap/source policy pins and required Security imports enforced; signed-artifact tests reject gate provenance mutation and a replacement binary lacking validation, without executing either.

Task 1 is implemented/verified; Task 2 is a partial user-operated access checkpoint. Gate A must be tested manually before accepting a real-window integration result. Tasks 3–5 (real message detection, overlays and full settings behavior), live gates and production promotion remain incomplete. The draft PR must not be merged as finished WhatsApp privacy protection.

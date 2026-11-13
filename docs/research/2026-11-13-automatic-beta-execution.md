# Automatic beta execution record — 2026-11-13

## Implemented and internally verified

Automatic-beta profile and `devyashtanwar.whatsapp-blur-auto-beta` identity; first-action-only Screen Recording request; strict private non-content preference schema and fixed-path store; offline authenticated window discovery; same shared scope/process/window validation before streams; two-window/pixel-budget policy; serialized retirement, bounded discovery and retry; independent screen/session conditions; no launch activation or window picker in normal mode; close-settings continuity; saved Pause and saved blur settings; names/avatars plus independent preview/conversation and hover choices; tint40–90/default65.

Real generated CMSampleBuffer → contentRect/scale normalization → local OCR → Gaussian → production publication path runs in the harness. The actual automatic coordinator factory is included in the harness. No real WhatsApp window, picker, capture stream or app bundle was launched by the agent; no permission was granted or changed.

## Independent review and fixes

A fresh read-only whole-branch review found no Critical and three Important issues. All three were fixed in one regression/fix pass:

- Automatic construction lost saved settings: actual factory/reconnection tests failed4 assertions, then passed after initializing the rendering coordinator with current settings.
- Rejected/expired imagery could be restored: changing-content age tests failed; publication now expires after its250ms retention budget and rejection clears cached image/plan/source. Harness verifies actual coordinator cache invalidation. Quiet images are retained only if no new content was observed; this cannot certify silent-stall health.
- Screen wake overrode session inactivity: interleaved screen/session tests failed2 assertions, then passed with independent conditions requiring both.

The latest non-GUI graph run passes355 core,15 configuration,21 geometry,107 compositor,43 integrated/factory and8 private-preference assertions (549 total). Signed automatic-beta build verifies exact policy, runtime hardening, sandbox-only entitlements, source provenance and linked APIs. Legacy lab tests pass35 region and131 AppKit view-tree assertions. Full suite passes82 Python tests with3 explicit authentic-app/live-PID fixture skips, plus77 legacy core assertions. Signed cover/lab/automatic-beta tamper checks pass; no app bundle was executed. Hosted CI has not yet run for this branch.

## Not production accepted

Generated processing samples observed cold242–464ms, warm1800×1400 median131–184ms and warm900×700 median68–92ms across small five-frame runs, some concurrent with compilation. These are not native capture-to-display measurements or credible p95 estimates. The proposed30fps/p95≤100ms changing-content target has not been met. No stale-mask reuse or trust relaxation was introduced to hide that limit.

User-only gates remain: real cross-process relative ordering/transparent overlap/Spaces/fullscreen/click alignment; actual permission prompts/revocation and retention across updates; real ScreenCaptureKit attachment conventions and Retina scrolling; startup/p95/CPU/GPU/aggregate memory; same-process window-ID reuse behavior. The separate invented-content visibility fixture is built but not launched; beta modules contain no fixture bypass. Production promotion remains blocked. This branch is for draft source review and harmless manual testing only.

## Rulings and costs

1. Implement independent components while user-only live gates remain pending. This avoids another planning stall; cost: code and synthetic tests cannot certify working privacy protection, so rollout stays blocked.
2. Window bounds do not prove opacity. Use verified normal-level native relative order for base rendering, conservative rectangles only for hover. Cost: actual cross-process ordering/transparent-overlay races need manual validation; no globally floating fallback is allowed.
3. Co-implement permission, lifecycle and UI composition as one shared review unit. Cost: a larger diff, mitigated by strict source pins and one independent whole-branch review.
4. Do not resolve review-declined live cases by guessing: ordering/input; OS grant/callback behavior; real attachment metadata; native performance/resources; exact same-process window-ID reuse all remain unverified. Cost: no claim of instant startup, complete coverage or production readiness; user acceptance is still mandatory.

No review minors were deferred. Root solid-cover permission budget is unchanged. The lab's default Gaussian context is unchanged; the native compositor explicitly supplies its reused graphics context to the same opaque filtering implementation.

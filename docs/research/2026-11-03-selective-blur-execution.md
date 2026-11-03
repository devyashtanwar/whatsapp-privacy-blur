# Selective native blur execution record

Plan: docs/research/2026-11-03-native-message-blur-feasibility.md.
Base: merged main 6dcc0dd. Work is isolated on codex/selective-blur-feasibility in the existing agent-owned checkout. User authorized implementation, commit and a new PR; browser/desktop operation and installed-app changes remain excluded.

Phase 1: Implemented synthetic native fixtures with 1/10/30 contact rows, generated previews/message bodies/attachment captions, visible names/header/composer, text-size/reorder/theme controls and manual acceptance instructions. No real chat data used. Visual acceptance pending user execution.

Phase 2: Implemented a separate AppKit/NSVisualEffectView experiment with per-region, transparent, non-key, click-through overlays. It uses public system materials and requires sandbox-only self-signature verification. No adjustable Gaussian-radius or successful live blur claim. Compile/sign/static verification and negative artifact checks are recorded below when complete; the GUI is not launched by the agent.

Phase 3: Instrumented fixture geometry tracks clipped view bounds and changes layout epoch on scroll/resize/reorder. Window-bounds-only evidence is deliberately unsupported, even when candidate rectangles are supplied. 30 behavior assertions cover names excluded, multi-row masks, stale/invalid clocks, duplicate/invalid masks, unsupported evidence, pointer exit, focus loss, bounded one-item reveal and layout invalidation. A pass-through scaffold failed 15 assertions before implementation; the implementation passes. Initial scaffold lacked CoreGraphics' CGRect Equatable overlay import; corrected that compiler issue before recording assertion RED.

Ruling: Production integration (Phase 4) must not proceed past the plan's two unfulfilled gates: actual material appearance needs user-run GUI acceptance, and exact external WhatsApp region discovery has no demonstrated provider under the current no-capture/no-Accessibility budget. Building an instrumented demo does not solve that information gap. Cost: this PR supplies a testable feasibility milestone, not the finished WhatsApp feature.

Ruling: Preserve the existing installed utility and all its source/capability policy; add the lab as a separate Swift package with distinct bundle ID. Cost: the user must launch the separate lab to evaluate appearance; merging this PR does not improve the existing cover's behavior.

No screenshot capture, accessibility-tree inspection, permission grants, global event monitor, third-party dependency, live WhatsApp discovery, private blur API, hidden helper or network code has been added to the lab. The build checks source and linked APIs, seals copied input hashes and signs/verifies only the sandbox entitlement and hardened runtime. It creates a distinct artifact in dist; no install or launch is performed.

Phase 5: Initial lab release build/static checks and five real signed-artifact tests passed. The independent review found one important hover pause/resume integration issue; regression/fix verification is recorded below. Live visual/UI, supported OS/display behavior, full-runtime network silence and actual WhatsApp geometry are explicitly pending. No phase requiring those facts is marked complete.

Final review finding: nil hover input while inactive reset expiry. Integration-sequence regression failed before the fix. Suspension now latches a required active pointer exit; it cannot be confused with an actual exit. No further critical/important issues identified by the independent reviewer.

Final: Ruling: Phase 1 fixtures and Phase 3 synthetic cases are partial, not completed visual acceptance. RTL/unusual text, generated images/replies, arrivals/search/archive still need dedicated scenarios. Cost: this draft cannot certify those layouts.
Final: Ruling: No GUI/runtime rendering, pointer/window ordering, display/Spaces behavior or network-silence check was run. The 50 ms refresh loop permits transient stale masks; do not claim immediate or zero-frame privacy. Cost: user-operated visual testing remains required and could reject this renderer entirely.

Final: fixed hover pause/resume finding — caller-sequence regression observed 1 failure, then 30/30 lab assertions pass after latching suspension until active pointer exit. Existing production build/signature/capability checks pass. Final combined suite and publication follow.

Final combined verification: 14 production core checks / 77 assertions / 0 failures; 57 Python tests / 0 failures / 3 explicit opt-in skips (authentic App Store, authentic Developer ID and live target PID not supplied). All four production and all five lab signed-artifact tests ran. Separate lab policy command: 30 assertions / 0 failures. Both release builds and static capability/signature checks pass; shell syntax and whitespace checks pass. No GUI was run. Draft feasibility PR publication is the next step.

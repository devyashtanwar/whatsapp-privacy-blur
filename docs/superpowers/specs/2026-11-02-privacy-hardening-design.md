# Privacy hardening design
User objective: a personally controlled macOS WhatsApp visual privacy utility, delivered as a PR in their fork, installed only after review.
User selected a solid cover instead of true blur and directed implementation to continue without browser/computer control.

## Approach
Replace screenshot blur with opaque AppKit windows. Remove Accessibility traversal, global event monitors and screen capture entirely. Read only on-screen window metadata through CoreGraphics and cursor position through AppKit. No third-party packages or network functionality.
Alternative considered: ScreenCaptureKit blur restricted to WhatsApp; rejected in favor of eliminating sensitive-pixel access. Keeping the previous capture code is unacceptable.

## Behavior and boundaries
- Full-window cover by default; optional sidebar + header coverage with validated manual width.
- Hover reveal off by default, allowed only while WhatsApp is foreground; immediately cover on focus loss.
- Track all visible layer-zero WhatsApp windows, including background windows, with normal-level overlays ordered immediately above their target. Do not float over unrelated foreground apps.
- One central timer only while enabled and WhatsApp is running. Disable/display sleep/session deactivation clear overlays and stop timer; resume recomputes state. Ordinary screen-lock notification delivery remains a live acceptance question; no lock guarantee is claimed. No screenshots under any state.
- Use primary-display global coordinate origin, clamp geometry and reject invalid records; do not read titles.
- No Accessibility, Screen Recording, keyboard, microphone, Full Disk Access or network entitlement.
- Build a hardened-runtime sandboxed app with local ad-hoc signing by default; optional trusted Developer ID identity. Do not pretend local signing is notarization.
- Installer stages/validates first, refuses replacement without explicit flag, never runs the app, never uses sudo or disables OS protection.
- No software installation, app launch or permission grant in this task. Tests must use synthetic window data, not the user's WhatsApp.
- OS window ordering, spaces/fullscreen behavior, screen-share capture modes, and app crashes cannot be certified by unit tests. Document these limits and manual acceptance checks.
Builder decisions: keep Swift/AppKit and macOS 13 minimum; remove obsolete blur controls; new fork bundle ID to avoid inheriting upstream settings/permissions. Automated build/tests and separate review before PR.

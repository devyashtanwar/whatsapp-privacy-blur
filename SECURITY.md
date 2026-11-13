# Security and privacy boundaries

## Data handled

The app reads local running-app metadata, on-screen window ownership/geometry, foreground app identity, current cursor position and the window under that cursor. The OS window-list API returns system metadata for windows; the code filters to WhatsApp process IDs and does not read window titles. It never requests chat text, account databases or screen pixels.

Enabled, coverage mode, hover preference and manual sidebar width live only in memory. They reset each launch; the app does not deliberately create preference/log/history files. Login launch is controlled through SMAppService; the displayed status comes from macOS rather than a separate saved preference.

There is no networking, telemetry SDK, remote update mechanism, clipboard reader, keyboard event monitor, shell execution or third-party dependency in the application. Build scripts invoke the local compiler/signing tools; those scripts are not bundled application behavior.

## Enforced build restrictions

The verified app is signed with App Sandbox and hardened runtime. Its only explicit entitlement enables the sandbox. It has no network-client/server, user-selected file, broad filesystem, Apple Events or device entitlement.

This restricts direct app capabilities; it is not proof against every OS bug, allowed system-service interaction or future altered implementation. Signing with `-` is local ad-hoc signing, not a verified publisher identity or notarization. Static symbol checks are regression guardrails and can be bypassed by a sufficiently different implementation; they are not malware detection.

The runtime startup gate refuses an unbundled/raw or incorrectly signed executable before target monitoring. Use the verified signed bundle. Future code/build changes require review again.

## Intentional limits

- An independent overlay cannot guarantee fail-closed secrecy. A crash, quit, process kill, metadata failure or OS ordering change can expose underlying WhatsApp content.
- Geometry/hover changes are reconciled every 0.1 seconds (with timer tolerance) and through workspace notifications. There can be transient coverage gaps; there is no zero-frame guarantee.
- Covers use normal window level and relative ordering above the target window. Cross-application ordering, full screen and Spaces behavior must be checked on the actual OS version. The app must not claim protection based on unit tests alone.
- Sidebar/header-only mode leaves chat bodies visible. Its manual width may not match a changed WhatsApp layout.
- Hover reveal deliberately exposes a window and can be accidentally triggered. It is off by default.
- Notifications, Dock previews, other accounts/apps, screenshots of the underlying WhatsApp window, and remote screen-capture modes are outside the guarantee. Separate overlay windows may not be included when sharing only WhatsApp.
- No protection from malware, someone controlling the logged-in account, WhatsApp itself, or the OS. This utility does not change WhatsApp's network/privacy practices.
- No runtime claim has been made about network traffic, sandbox compatibility, or live concealment until acceptance testing is completed after review.
- There is no dedicated ordinary-screen-lock handler. Display-sleep and user-session notifications stop monitoring, but their delivery during ordinary locking has not been verified. No lock-specific monitoring guarantee is made.

## Verification

Run `./scripts/test.sh` and `./build-app.sh`. The latter runs `scripts/verify_app.py` without executing the app. Consult README's manual acceptance checklist before personal use.

For vulnerabilities, report a minimal technical reproduction privately to the fork owner where an appropriate private reporting channel is available. Do not include chat contents, tokens or personal files in public issues.

## New enforcement and provenance
The signed local capability policy and exact entitlement allowlist are checked both by packaging and at startup. Known network, browser/URL broker, sensor/location, personal-file, Keychain-secret, clipboard, shell and persistence routes are excluded by source review and regression guardrails. Cursor/hit-test metadata is sampled only with explicit hover enabled. Certificate validation never enables network-assisted trust.

Process selection requires Apple-anchored running code with the pinned WhatsApp identifier and publisher, not an identifier string alone. A signature failure produces no cover or permission prompt. The Mac App Store branch requires the Apple Store signing certificate class plus exact signed team/application entitlements; the Developer ID branch requires the fixed publisher OU and Developer ID certificate class. Read-only offline checks of an authenticated App Store fixture and running process, including a sandbox-only CLI harness, pass. The GUI overlay still requires live acceptance; a genuine Developer ID fixture remains unavailable. See docs/runtime-capability-audit.md.

Compilation uses a private, fixed copy of source/build inputs and records hashes of those same bytes. Install paths are canonicalized before staging, publication is serialized and uses Darwin atomic no-clobber renames, and recovery preserves an old backup instead of overwriting a conflicting new destination. These measures do not guarantee power-loss transactions or defeat arbitrary malicious same-user filesystem tampering.

All code-validity checks explicitly disable network-dependent evaluation. Offline validation cannot retrieve fresh online revocation/notarization status; it preserves the Apple anchor and fails locally rather than enabling online verification.

Authentication failure details (stage and optional Security status/message) remain in memory and can be viewed locally. The retry action clears cached results; it cannot authorize a failed target. No diagnostics are persisted or transmitted.

## Separate native Gaussian test candidate

`Experiments/DesktopIntegration` has a separate automatic beta (`devyashtanwar.whatsapp-blur-auto-beta`). The user approved macOS Screen Recording permission, in-memory local OCR and private non-content preferences. Programmatic discovery receives catalog metadata but creates only independent authenticated WhatsApp window filters; no unrelated pixels or window titles are read. OS permission is broader than this application-level scope. The only persisted data is the strict enabled/paused and blur-settings schema in the sandbox's private container. Network/audio/Accessibility/personal-file grants remain absent. Root cover capability rules are unchanged.

The beta is not verified privacy protection. Real ordering/coverage/input alignment and permission retention are pending. Synthetic large-window processing misses the proposed smoothness target; do not promote to production based on passing isolated tests. See the [beta limits and acceptance guide](Experiments/DesktopIntegration/README.md).

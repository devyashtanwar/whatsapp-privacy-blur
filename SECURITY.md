# Security and privacy boundaries

## Data handled

The app reads local running-app metadata, on-screen window ownership/geometry, foreground app identity, current cursor position and the window under that cursor. The OS window-list API returns system metadata for windows; the code filters to WhatsApp process IDs and does not read window titles. It never requests chat text, account databases or screen pixels.

Only Enabled, coverage mode, hover preference and manual sidebar width are stored using UserDefaults in the app's normal preference/container storage. Login launch is controlled through SMAppService; the displayed status comes from macOS rather than a separate saved preference.

There is no networking, telemetry SDK, remote update mechanism, clipboard reader, keyboard event monitor, shell execution or third-party dependency in the application. Build scripts invoke the local compiler/signing tools; those scripts are not bundled application behavior.

## Enforced build restrictions

The verified app is signed with App Sandbox and hardened runtime. Its only explicit entitlement enables the sandbox. It has no network-client/server, user-selected file, broad filesystem, Apple Events or device entitlement.

This restricts direct app capabilities; it is not proof against every OS bug, allowed system-service interaction or future altered implementation. Signing with `-` is local ad-hoc signing, not a verified publisher identity or notarization. Static symbol checks are regression guardrails and can be bypassed by a sufficiently different implementation; they are not malware detection.

Use the signed bundle, not `swift run HideWhatsApp`, when evaluating the configured confinement. Future code/build changes require review again.

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

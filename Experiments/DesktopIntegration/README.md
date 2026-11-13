# WhatsApp Blur Automatic Beta

The automatic Desktop integration is an **experimental review build, not verified privacy protection**. It replaces repeated window picking with authenticated WhatsApp discovery after macOS Screen Recording permission. Real window ordering, message coverage, input alignment and performance still need manual acceptance. Do not use sensitive chats to test it.

## What is implemented

- Automatic attachment with either app launch order, delayed windows and bounded reconnection after ordinary window changes.
- Up to two ordinary visible WhatsApp windows within a conservative pixel budget; unsupported/additional windows are explicitly partial or unavailable.
- Independent sidebar previews, conversation messages, names and avatars. Separate optional hover reveal for previews and messages; identity never reveals on hover.
- Tint 40–90%, default 65%, over opaque Gaussian-filtered pixels.
- Settings close keeps capture running. Pause stops capture and saves disabled state. Quit stops capture while preserving your saved enabled state for the next explicit launch. No login item is installed.
- Fixed private-container preference file containing only enabled state and blur settings. Corrupt or redirected preferences disable startup capture and show an error.

## Permission and privacy boundary

macOS Screen Recording permission is broader than WhatsApp. The implementation narrows it to independent windows belonging to an offline-authenticated official `net.whatsapp.WhatsApp` process. Discovery receives system catalog metadata, discards unrelated windows and does not read titles or capture unrelated pixels. No display or app-wide capture fallback is allowed.

The entire authenticated WhatsApp window can reach memory, even in sidebar-only mode. Local Vision OCR and rectangle detection infer regions. Pixels and recognized text are never saved, logged or transmitted. The bundle has only the sandbox entitlement and hardened runtime, with no network, audio, microphone, camera, location, Accessibility, input monitoring, clipboard or personal-file access grants. This does not restrict WhatsApp's own networking or permissions.

The beta uses a separate click-through processed image, rather than changing WhatsApp itself. Missed regions can stay readable. The image can lag the live window, and clicks still reach live WhatsApp. Capture failure, unsupported layouts, permission loss, quitting or a crash exposes original content. Observed changing content expires a prior full-window image after its 250 ms retention budget; withdrawing it also exposes WhatsApp. A quiet image is retained only while no newer content was observed, which cannot prove a silently stalled stream is healthy. Startup cannot hide content before the companion attaches and renders. It does not secure notifications, screen sharing, screenshots or malicious software.

## Build for manual testing

Requires macOS 15.2+, compatible Apple Command Line Tools and Python 3. In the checkout containing this branch:

```bash
./scripts/test-desktop-preview.sh
./scripts/build-desktop-preview.sh
```

The output is `dist/WhatsApp Blur Automatic Beta.app`, bundle ID `devyashtanwar.whatsapp-blur-auto-beta`. The builder verifies immutable source inputs, sandbox-only entitlements, hardened runtime, fixed capability profile and linked APIs. It does not launch or install the app. **Do not use the root `install.sh`: it installs the separate solid-cover product.**

Quit earlier Blur/Cover/Preview processes yourself. Open the new bundle manually, then open its menu-bar Settings. Select **Enable / Resume automatic blur**. Review and grant Screen Recording in macOS yourself, restart the beta if macOS requests it, then Resume. Permission is never requested at launch or by retries. Settings show the build identifier so an old process can be distinguished from a new build.

Keep a stable app path when testing. Local ad-hoc signing is not notarization and rebuilds may require renewed permission; retention has not been verified. A consistent Developer ID identity may improve continuity, but this project never creates certificates or weakens validation. Do not bypass macOS security controls.

## Acceptance checklist

Use invented self-chat content only. Test all of the following against the same build:

1. Blur first, then WhatsApp; WhatsApp first, then Blur; delayed window creation and WhatsApp restart. Check the status and actual blur, not only the capture indicator.
2. Settings close, another app in front, partial overlap and transparent voice overlays. Blur must remain on exposed WhatsApp without painting above other apps. A separate [invented two-process ordering fixture](VisibilityFixture/README.md) tests this without real chat pixels.
3. Each category alone and in combinations; archived lists, ordinary conversations, text/media, replies, RTL and clipped rows. Check names/avatars remain clear when disabled and never reveal when enabled.
4. Rapid clicks, scroll and momentum, chat changes, hover after scrolling, 40/65/90% tint, themes, movement, resizing and display changes. Any readable fragment, stale click target or incorrect region is a failed acceptance case.
5. Pause and restart: capture must stay off. Resume, quit and restart: saved enabled mode may reattach after permission/authentication. All categories off must stop capture. Lock/sleep must stop and wake must revalidate.
6. Two windows, an oversized/additional window, permission revocation and denied setup. Partial/error status must never imply every window is covered.

## Evidence and current gate

Automated tests use invented pixels and memory-only preference I/O; they never launch a GUI or stream, inspect WhatsApp or grant permission. They cover real CMSampleBuffer decoding and transforms, actual OCR/Gaussian processing and publication, stale results, lifecycle policy, strict preferences and signed-artifact rejection.

Generated runs on this development machine observed about **242–464 ms cold whole processing**, warm 1800×1400 medians of **131–184 ms**, and warm 900×700 medians of **68–92 ms** (five frames per size per run). Some runs overlapped compilation; these are small development samples, **not controlled capture-to-display measurements**. The proposed 30 fps / p95 ≤100 ms changing-content target is not met at the larger size. Live startup, memory/GPU totals, cross-process ordering, Spaces/fullscreen and permission retention remain unmeasured. Production promotion is blocked; the automatic lifecycle does not solve OCR/mirror latency.

Do not post private screenshots, OCR text or chat contents in public issues. Report non-content status, build ID and a harmless reproduction.

# WhatsApp Desktop blur — native test candidate

This build now processes the explicitly selected native WhatsApp window and renders localized Gaussian blur over detected regions. It is neither the old solid-cover app nor the synthetic demonstration. **Coverage and scroll/hover behaviour in real WhatsApp remain unverified. Use harmless test chats, not private conversations.** It never reports “protected.”

## Implemented controls

- Independent sidebar-preview, conversation-message, contact/group-name and avatar switches.
- Optional separate sidebar/message hover reveal, requiring pointer movement after a 150 ms settled period, for up to two seconds. Identity is never intentionally revealed by hover.
- Tint from **40% to 90%, initially 65%**, applied over opaque Gaussian-filtered pixels, without blending in sharp source text. Names/avatars and both hover switches initially off; both message blur switches initially on.
- Explicit selection, pause/stop, session-only settings and local processing. All categories off stops capture. Closing settings stops capture; minimize or return to WhatsApp to test while keeping it running. Resume requires selecting again.

The renderer publishes a whole processed image with only selected regions blurred and other UI unchanged. This keeps the image and its masks together instead of moving independent patches over changing messages. It can visibly lag or freeze during analysis; this is not WhatsApp's own rendering pipeline. Clicks pass through to live WhatsApp, so a delayed image can mismatch live controls. Use a harmless self/test chat and avoid sending sensitive content. Incoming complete frames revoke hover immediately and restore the last fully blurred processed frame. The companion cannot intercept another application's scroll/click before macOS delivers a frame.

## Processing and limits

The user explicitly authorized on-device OCR in this test app on 2026-11-12. Apple Vision receives only pixels of the system-picker-selected, authenticated native WhatsApp window. Recognized strings stay local to the OCR request; only geometry and whitelisted UI labels leave it. No content logging, image/text export, networking, telemetry, saved selection/settings, Accessibility, event taps, keyboard/clipboard monitoring, microphone, camera, location or WhatsApp database access. The bundle has only the App Sandbox entitlement and hardened runtime. The app reads its own bundled policy/signature metadata; macOS frameworks may maintain their own system caches.

Sidebar detection uses an English Search anchor or the Archived header with persistent pane boundaries; it no longer requires an opened conversation. Conversation detection still requires an empty composer with “Message”/“Type a message” visible. It infers sidebar name/preview pairs from observed text baselines, and uses text/rectangle observations for conversation/media regions. These are **experimental heuristics, not supported-layout evidence**: media can be missed, sender names or timestamps misclassified, row pairs wrong, and avatars inaccurately bounded. RTL, replies, emoji-only content, unusual themes/scales/layouts and clipped rows are not certified. Typing can remove the composer anchor and make conversation detection unavailable; independently detected sidebar regions can still render. The app withdraws rendering rather than guess a full-pane mask when anchors cannot be found. This exposes original WhatsApp; it is not a fail-closed privacy product.

Only one rendering job and one newest pending frame are scheduled. App-owned current/pending images and worker temporaries remain in memory; Stop releases queued/display references, and an already-running synchronous Vision/filter request may finish before its references are released. Its result cannot revive the stopped session. This is not forensic zeroization. The selected window can reach memory in its entirety even in sidebar-only mode.

Foreground identity, current bounds and above-window occlusion are checked before presentation. Occlusion checks read window IDs, bounds and alpha metadata, not titles/pixels. Rendering is withdrawn on loss of current visibility; no overlay guarantee exists for focus changes, occlusion, Spaces, full screen, multiple displays, resize, crashes, recording or sharing only WhatsApp. Moving or resizing the window can stop capture and require selecting again. Picker permissions remain under macOS control; no display/app-wide capture fallback is implemented.

## Build and manually test

Requires **macOS 15.2+**, compatible Apple Command Line Tools and Python 3. The older cover's requirements remain unchanged. Quit the running **WhatsApp Blur · Desktop Test** app before rebuilding, so opening the bundle cannot reactivate the old process. In your checkout, select the PR branch (do not discard local changes):

```bash
git fetch origin
git switch codex/desktop-blur-integration
git pull --ff-only
./scripts/test-desktop-preview.sh
./scripts/build-desktop-preview.sh
open "dist/WhatsApp Blur Integration Preview.app"
```

The build stages immutable source inputs, reuses the exact existing offline WhatsApp identity validator and Gaussian filter, signs locally and verifies the separate bundle `devyashtanwar.whatsapp-blur-preview`. No external runtime dependency or model download is added. Local ad-hoc signing is not notarization. Do not disable macOS security controls to bypass a warning.

**Do not use `install.sh` for this candidate**: that builds/installs the old solid-cover product. You can test the new bundle directly from `dist`; it need not replace an installed app. Quit the old cover yourself first if it obscures WhatsApp.

1. Open a harmless self/test conversation in native WhatsApp. Archived lists can be tested without an opened conversation. For conversation testing, keep the empty composer placeholder visible. Start with text plus one harmless image message.
2. In the test app choose **Choose WhatsApp window…**, explicitly select that one window in Apple's picker, then return to WhatsApp. There must be no capture at launch, no non-WhatsApp acceptance and no automatic reattachment. Cancel any request for blanket access and report it.
3. Expect either **Experimental rendering** with a detected-region count or an explicit unavailable/error status. The former does not mean complete privacy. If no blur appears, report the full status and WhatsApp/macOS versions. Initial-image timeouts now include only non-content callback status.
4. Try sidebar-only and conversation-only, then both. Names/avatars should remain visible unless requested. Archived view must render sidebar regions independently; conversation detection there may be explicitly unavailable. Test names-only/avatars-only and combinations. Check every text line, image, reply, sender name and clipped row; report any missed or over-blurred areas.
5. Enable each hover setting separately. Move onto an item after scrolling settles; only that detected item should reveal, for at most two seconds. Moving off or receiving another frame must restore blur. Enabled identity blur must remain. Animating UI can continually revoke hover; this needs real acceptance testing.
6. Test rapid clicks, scroll/momentum, chat changes, tint 40/65/90%, theme changes, occlusion and focus switching. Check for image lag, gaps and readable fragments. A discrepancy is a failed acceptance case, not something to ignore because automated tests passed.
7. Stop, turn all four categories off, or close settings. Confirm the system capture indicator stops. If startup/shutdown cannot be confirmed within the lifecycle timeout, the candidate closes itself. Relaunch must forget settings/selection.

Do not send private screenshots, OCR text or chat contents in public issues. A harmless native test screenshot and version can help improve the detector without inspecting your desktop. Real-message acceptance remains required before production promotion or relying on the app for privacy.

## Automated checks

`./scripts/test-desktop-preview.sh` runs settings/session/picker/publication/hover tests, actual capture-configuration checks, generated-image OCR/layout probes and compositor pixel checks. These tests open no picker/window/stream and never inspect WhatsApp. Signed-bundle rejection tests run with `PRIVACY_DESKTOP_PREVIEW_APP` pointing to the built bundle; they never execute it. Test success is not real native coverage, performance or absence-of-disclosure evidence.

## Quiet-window and startup handling

A usable `.started` image is validated like a complete image; a status value alone is never image evidence. The first usable image has a 15-second deadline, and idle callbacks cannot extend that deadline. Once an image has arrived, a quiet window no longer triggers a three-second disconnection. Explicit error/suspended/stopped events, target/bounds changes, Stop and session loss still invalidate capture. No timer fabricates a fresh image or source timestamp. A retained processed image may be shown while waiting for new pixels, with hover paused if its receipt is too old. This cannot distinguish every silent framework stall from unchanged content; no live/protected status is inferred from silence.

The selected window may now be analyzed while picker/settings has focus, allowing its first image to be prepared before returning to WhatsApp. Presentation still checks current process/session/window binding, foreground and occlusion. Startup diagnostics contain status categories only, never OCR strings, titles or images.

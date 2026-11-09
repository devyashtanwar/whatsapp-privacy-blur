# WhatsApp Desktop integration preview — access checkpoint

**This build does not blur real WhatsApp messages.** It is the first integration checkpoint in the approved production plan, not an upgrade to the installed cover or the synthetic lab. Message geometry and external scroll synchronization are not implemented/proven. The app never reports that your messages are protected.

## What this checkpoint does

- Starts idle; window access requires your deliberate button press and system picker selection each time.
- Accepts one complete test frame from the selected, authenticated native WhatsApp window, checks metadata, then stops access. Further callbacks during asynchronous shutdown are discarded. No frame image is displayed, converted, saved or logged.
- Rejects displays, app-wide/multiple-window selections, unknown owners and offline publisher/authentication failures. Uses the system-issued picker filter after validating its scope. No general screen-content enumeration or broad permission fallback.
- Offers the four requested settings for future integration: sidebar previews, conversation messages, names and avatars. These settings **do not apply blur in this checkpoint**. Tint is 40–90%, initially 65%. Names/avatars default off. State is session-only.
- No audio, microphone, camera, location, Accessibility, keyboard/clipboard monitoring, chat databases, networking, telemetry or hidden helper. The app is signed with hardened runtime and the sandbox entitlement only. The OS still controls picker consent; signing does not replace it.

## Requirements and build

macOS **15.2 or later**, plus compatible Apple Command Line Tools. The picker itself exists on 14, but inspection of its exact included windows/displays/apps requires 15.2. The older cover and lab OS floors are unchanged.

From the repository checkout:

```bash
./scripts/test-desktop-preview.sh
./scripts/build-desktop-preview.sh
```

The build compiles a private fixed snapshot, including the existing offline process identity implementation, and verifies the distinct bundle `devyashtanwar.whatsapp-blur-preview`. It writes only the generated artifact under `dist`. It does not install or launch anything. Do not run the snapshot package directly; the scripts stage its authenticated shared inputs first.

Local ad-hoc signing is not notarization. Do not disable macOS security settings to bypass a warning; report it instead.

## User-operated Gate A test

1. Quit the old cover yourself if it obscures WhatsApp. Keep actual private chats out of view; use a harmless conversation for this test.
2. Launch the preview yourself:

   ```bash
   open "dist/WhatsApp Blur Integration Preview.app"
   ```

3. Confirm the preview says **no blur is active** and that no system picker/capture starts by itself.
4. Choose **Test WhatsApp window access…**, then explicitly select one native WhatsApp window in Apple's picker. This authorizes pixels of the entire chosen window, regardless of the future blur switches.
5. Expect the status to report that the access test passed and access stopped, while message detection remains unavailable. Check the macOS capture indicator ends. If a valid frame does not arrive, the test times out after 15 seconds. Stop remains pending until startup/shutdown callbacks settle; if shutdown cannot be confirmed within five seconds or returns an error, the preview closes itself. No raw frame/screenshot is needed in your report.
6. Try Cancel. Optionally pick a non-WhatsApp window containing no private material: it must be rejected before a stream is created. Stop window access and closing the preview must stop the session. No selection should be remembered on relaunch.
7. Check names-only and avatars-only settings still allow the access test; all four blur switches off must disable selection. These controls change future coverage, not current capture scope.
8. Report only the displayed status, macOS version and whether the system capture indicator stopped. If macOS requests blanket access, cancel and report it; do not broaden permission to make this test pass.

Success validates only this machine's selected-window access path. It does not validate real-message region detection, Gaussian readability, per-item hover, scroll/privacy behavior, overlays in window sharing, lock handling or other OS/display modes. Those remain Gates B and C before production promotion. If they fail, implementation must stop or return for a new reviewed approach, not silently weaken access restrictions.

## Automated checks

`./scripts/test-desktop-preview.sh` runs pure settings/session/scope/policy tests and tests the actual ScreenCaptureKit configuration object. It constructs no picker, window or stream. Signed-artifact negative tests run with `PRIVACY_DESKTOP_PREVIEW_APP` pointing to a built bundle; they never execute it.

All preview files/build/capability rules are separate from the existing installed cover and lab. No login launch, saved selection, automatic resume or production replacement is included.

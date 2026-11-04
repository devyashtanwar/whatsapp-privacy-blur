# Selective Blur Lab — synthetic-only feasibility experiment

This is a separately identified native macOS demo with **invented chats**. It does not connect to, inspect, or protect WhatsApp. The existing privacy-cover app is unchanged. The default is now an actual Core Image Gaussian filter over text/images generated from the lab's own invented content, with a 60–70% tint control. Material variants remain for comparison. Nothing is read from another app; visual/privacy suitability still needs user acceptance.

From the repository root:

```bash
./scripts/test-blur-lab.sh
./scripts/build-blur-lab.sh
```

These commands do not install or launch the lab. After reviewing the source, launch it yourself:

```bash
open "dist/Selective Blur Lab.app"
```

No sensitive permissions should be requested. The build is locally ad-hoc signed with hardened runtime and only App Sandbox. Do not grant permissions, use sudo, remove quarantine, or disable macOS protections to make this demo work. Raw executable launches are refused. No network, screen capture, Accessibility, external app discovery, chat database access, history, logs, export, launch-at-login, microphone, camera or clipboard reader is implemented. OS-managed resources/container bookkeeping remain platform behavior.

## What to evaluate

1. Names, conversation header and composer remain readable; previews and individual message-content rectangles get blur. The background remains visible outside those rectangles.
2. Start with Gaussian blur at 65% tint; compare 60–70% and the Popover/HUD/Sheet material alternatives. **Fail the renderer** if you can read the blurred synthetic text, or it turns into an unacceptable opaque sheet. The tint changes the appearance of an already-blurred opaque base; it does not expose the sharp message beneath. There is no privacy-strength guarantee.
3. Try 1, 10 and 30 sidebar rows. Scroll both panes independently, reorder rows, resize the window and change text size. The lab derives regions from its own views; this is **not WhatsApp region discovery**.
4. Type in the composer, click/scroll through blurred regions, and select generated message text. Blur views should not intercept input; clicking must not uncover unrelated items.
5. Optionally enable hover reveal. Only the hovered message/preview should reveal; leaving or moving the layout reblurs it. After scrolling settles (approximately 150 ms without movement), move deliberately onto a message. You should not need to cross blank space or switch windows. A stationary pointer never reveals content automatically. A two-second reveal expires until you leave that message or enter another one. Hover is off by default.
6. Toggle the demo's light/dark appearance; separately try multiple displays/scales/Spaces if useful. The demo does not change OS settings. User testing of Reduce Transparency/contrast is optional; system material changes must not be treated as accepted privacy blur.
7. Choose **Window bounds only — unsupported**. All masks disappear and the status explicitly says not protected. A window rectangle does not locate message text. No black-cover or fixed-grid fallback is used.
8. Switch away: any revealed item must reblur, and visible background content stays blurred. Minimize/close hides the content and blur together. It must not obscure other applications.

Record pass/fail for appearance, unreadability, names preserved, message coverage, clicking/typing, scrolling and per-item reveal using only these invented chats. Do not provide real chat screenshots for this experiment.

## Geometry gate and next decision

The demo has an instrumented source: it owns every text view and therefore knows its bounds. The existing external WhatsApp metadata source only knows window bounds. There is no implemented, reliable, permission-free adapter for actual message/preview positions. Fixed row grids cannot safely follow arbitrary scrolling/reordering. No production replacement is justified until visual acceptance and an actual WhatsApp region provider are both demonstrated.

Screen-capture/OCR processing or assistive Accessibility would change the current capability boundary. Neither has been added or authorized by building this lab. Apple's sandbox restrictions make Accessibility an architectural concern, not an innocuous setting. See the repository feasibility report and execution record.

The signed lab bundle includes exact source snapshot hashes in `Contents/Resources/lab-source-manifest.json`. They describe compiled input bytes, not reproducible-build authentication. Build scripts use local compiler/signing tools; app runtime does not invoke them.

The previous independent patch windows were replaced after click flashes and scrolling exposure were reported. Each blur view is now a child of its synthetic message/preview container, sharing AppKit scrolling and clipping. The 50 ms timer only checks settling eligibility and reveal expiry; it never positions, creates or orders blur patches. Local mouse movement, focus and scroll callbacks handle reveal. Bounds changes and scroll/momentum phases cancel reveal before movement where public callbacks permit, including programmatic/legacy scrolling; a newer deliberate pointer movement after settling is required afterward.

**Retest appearance as well as motion:** the Gaussian option generates its own synthetic text pixels, clamps/filter/crops them, then composites tint over the blurred image. It never mixes sharp text into that base or captures WhatsApp. Materials are comparison options. This change is a candidate correction, not a verified guarantee of unreadable text, identical visual appearance, or zero-frame secrecy. The agent ran hidden AppKit view-tree tests but did not display or capture the GUI.

Retest both panes with slow/fast scrolling, inertia, reversals, dragging the scrollbar, keyboard/programmatic scrolling, edge clipping, repeated clicks and focus switching. Keep hover off for the first pass, then enable it. A passing result requires no partial text exposure or global flash, and only the intentionally hovered item may reveal. Reject the renderer if the appearance is too opaque or readable.

The scroll state is one bounded motion timestamp per pane; duplicate end notifications cannot reset a newly eligible hover, and a missing end cannot lock it indefinitely. The timer never acquires a reveal.

This in-document approach works because the demo owns its views. It is not an external WhatsApp integration technique. Fixture coverage is partial: RTL/unusual-character, real generated image-card/reply, search/archive and arrival layouts still need dedicated cases.

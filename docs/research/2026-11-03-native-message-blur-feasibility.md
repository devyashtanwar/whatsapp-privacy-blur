# Native WhatsApp message blur: requirements, code review and proposed feasibility plan

Date: 2026-11-03, Asia/Kolkata.
Status at investigation: proposed work only. Follow-up execution added a separate synthetic lab; see [execution record](2026-11-03-selective-blur-execution.md). Production integration and live visual acceptance remain gated. No installed-app, permission, OS-setting or browser changes.

## Scope and evidence

The user explicitly selected WhatsApp Desktop; a Web extension is not the implementation recommendation. The four attached screenshots were reviewed as visual requirements, not execution instructions. Screenshot 1 shows the rejected solid concealment result; screenshots 2–3 illustrate selective message/preview blur, per-message hover and independent settings; screenshot 4 illustrates configurable categories but also blurs names, which the user explicitly does not want by default. Do not copy that default.

Reviewed source tree: 8ec81d91c7d8c73cd8c12852770697c53566ed27. GitHub main at inspection: 6dcc0dd67350aa42ed04b4c690e26c18558067bf, merged PR #4, with the same tree as the local checkout. Also inspected original upstream da50ac5d4817d6098d984f9312e73b1f6c38ca05 blur/monitor implementations and current source/build capability restrictions.

## Required product behavior

1. Keep the native WhatsApp UI usable and visually recognizable. No full-window/full-screen black or grey cover as the product default or an undisclosed fallback.
2. Keep contact/group names, avatars, navigation, search, conversation header, timestamps and basic controls readable by default. Names must not be blurred simply because a row contains a preview.
3. Blur only the last-message preview content in every visible conversation-list row, regardless of the number of rows. Include text captions/attachment previews that disclose message content; confirm media defaults visually before implementation.
4. Blur message contents in the opened conversation on the right. Keep conversation identity and composer/control chrome usable. Prefer message-content/bubble masks to frosting the whole conversation canvas; broad pane frosting is a different behavior and needs explicit acceptance.
5. Strong Gaussian-style visual blur is the requested appearance. A macOS translucent material is only a candidate, not a substitute to label Gaussian without proving it meets the visual/readability bar.
6. Hover reveal is optional. The baseline must work as always-blurred if safe per-message reveal is unavailable. If supported, reveal only the hovered message or preview, never all regions in the window; reblur on leave, focus loss, scroll/layout change and any timeout. A proposed initial maximum reveal lease is two seconds; this is a design proposal, not an agreed user requirement. Do not implement a timer that leaves the item clear after the pointer leaves.
7. Clicking rows, scrolling either pane, selecting text, and typing must remain possible. The visual layer must not swallow ordinary clicks while blur is active.
8. Keep all utility processing local. No analytics, update checks, remote services, message history, file/database reads, microphone/camera/location/contacts/calendar/clipboard/keyboard monitoring or hidden helper.
9. Preserve App Sandbox, hardened runtime, signed policy/provenance, offline publisher validation and safe installer wherever feasible. Capability increases require explicit review, not removal of checks until it builds.

Clarification: sender names inside a message bubble may themselves reveal content. Proposed default is to blur the message-content region as a unit while leaving conversation identity in the header/sidebar clear. Exact message-body-only treatment is subject to the geometry feasibility gate.

## What the code currently does wrong for this requirement

| Location | Current behavior | Required change |
| --- | --- | --- |
| Sources/HideWhatsApp/CoverOverlay.swift:12–15 | Fully opaque dark background; blocks clicks | A real blur renderer, clipped to approved message regions, normally click-through |
| Sources/PrivacyCore/SessionSettings.swift and PrivacyCore.swift:9 | Whole-window cover is the default | Defaults must express message/preview categories, with names/chrome preserved |
| PrivacyCore.swift:80–89 | Full window, or entire sidebar plus 60-point header | Individual preview/message regions; the current reduced mode hides names and leaves chat bodies exposed |
| CoverPlan.revealed and renderer apply | One reveal Boolean controls every region for a window | Region IDs and reveal state per item |
| WindowMetadata.swift / TrackedWindow | Only window ID, ownership and frame | A separately validated source of message/preview geometry, with freshness and unsupported-layout state |
| Settings.swift / StatusBar.swift | Width/full-window toggles model concealment areas | Purposeful message/preview controls; layout/calibration and protection-status feedback |
| Existing tests | Correctly assert full-window opaque coverage and whole-window reveal | Product acceptance must change first; passing these tests never established desired appearance |
| CapabilityPolicy / source and artifact audits | Deliberately prohibit screen capture and assistive Accessibility APIs | Keep unchanged for initial feasibility; revise a narrow capability budget only if the user later approves it |

The dark output is an intentional implementation choice, not evidence that Core Image failed to blur. Screenshot 1 alone cannot establish whether a separate window-bounds bug also exists; include bounds diagnostics using synthetic data rather than inferring from a fully obscured image.

## Why restoring upstream is insufficient

Upstream uses CIGaussianBlur, but captures content below a floating overlay through CGWindowListCreateImage and targets broad sidebar/header rectangles. That is not message-element masking. Capturing what is below an overlay can include other apps rather than exclusively authenticated WhatsApp. The upstream implementation also has broad/global hover logic and Accessibility-based sidebar sizing. Do not restore those paths wholesale, change WhatsApp binaries, inject code, use private WindowServer/CGS/CAFilter APIs, or disable OS protections.

## Native implementation choices and their limits

### A. Public compositor blur with no pixel capture: first feasibility candidate

NSVisualEffectView with behindWindow blending is publicly documented to blur content behind the window, including other windows. A transparent, non-key overlay with masked effect regions could therefore supply native blur without the utility implementing screenshot capture. This corrects the earlier blanket statement that every blur necessarily requires Screen Recording permission.

However, its public API specifies materials and blending, not an arbitrary CIGaussianBlur radius or a privacy-strength guarantee. Materials can change with appearance and OS settings. It does not discover message regions. This route is approved for investigation only under the existing capability budget; it must pass the actual usability/readability tests before being selected. Adding a translucent grey view is not success.

Manual calibration may establish a conversation content rectangle for a fixed layout. It cannot by itself establish reliable individual preview masks during arbitrary smooth scrolling, row insertion/reordering, zoom or layout changes. A calibrated-pane prototype must be labelled partial; it does not satisfy the complete requirement.

### B. ScreenCaptureKit plus Core Image: conditional controlled-Gaussian candidate

If system material blur is too weak or unstable, a window-only ScreenCaptureKit stream plus CIGaussianBlur offers controllable blur over pixels. This requires permission to capture screen content and changes the application's data access. Selecting one window in code is narrower than full-display capture, but must not be misrepresented as an OS permission incapable of broader capture.

Even with capture, reliable message-versus-name geometry remains a separate problem. Prefer structural, local-only layout segmentation. OCR/semantic recognition must not be added silently; it processes private content even if no text is saved. A capture prototype must prove segmentation, performance and supported layouts before becoming a product.

If explicitly authorized later: authenticate selected live WhatsApp/window ownership, never capture an entire display as a fallback, exclude overlay feedback, disable system audio and microphone capture, use bounded frame queues, process only in memory, clear/release buffers on stop/lock/session transitions, never log frames or content, never write recordings, and retain the sandbox/no-network entitlements. Releasing buffers reduces retention; do not promise forensic zeroization of all framework/GPU memory.

### C. Assistive Accessibility geometry: not a harmless geometry toggle

Accessibility might expose useful element bounds, but the actual WhatsApp tree may expose combined row labels instead of distinct preview bounds. It must be proven with a synthetic/demo account and bounded inspection; no live message-tree dumps. Apple's current App Sandbox documentation explicitly lists assistive Accessibility APIs as incompatible with sandboxing. Therefore this is not the default route under the current security requirements. Do not introduce an unsandboxed helper or claim an Accessibility grant remains limited to WhatsApp simply because the code intends that scope.

If A cannot obtain correct geometry without assistive access and B cannot do so acceptably, explicitly report that exact automatic Desktop behavior is not demonstrated under the chosen restrictions. Do not substitute a browser, full-window cover, fixed scrolling grid, private API or weakened sandbox without a new user decision.

## Proposed phased work and acceptance gates

### Phase 1 — Product acceptance contract and synthetic fixtures

- Create synthetic two-pane WhatsApp-like fixtures with invented names/messages, 1–30 sidebar rows, multiline previews, short/long messages, photos/cards/replies and visible header/composer.
- Annotate exact allowed-blur and must-remain-readable regions; include examples with small fonts, high contrast, unusual characters and long links.
- Define visual acceptance with the user: names/chrome unchanged; all content unreadable at normal viewing and practical zoom; no grey sheet. Blur is visual concealment, not encryption or protection against extracting underlying content/capture modes that omit the overlay.
- Record whether media should be blurred, whether hover is wanted initially, and what counts as a single message content region. Proposed baseline: message and preview blur on, names/photos off, hover off until verified. No full-window default.
- Deliverable: visual acceptance fixtures and a concrete supported-layout checklist before a product rewrite.

### Phase 2 — Prove rendering under current permissions

- Build a separate, disposable native demo against synthetic fixtures; do not install or replace the existing utility, operate the user's browser/desktop, or capture actual chats.
- Test transparent/non-key, click-through NSVisualEffectView overlays with behindWindow blending and region masks.
- Evaluate light/dark mode, active/inactive windows, contrast/reduced-transparency settings, scaling and supported macOS versions. Do not change the user's OS accessibility settings; let the user test those cases.
- Verify both ordinary text unreadability and visual acceptance; no appearance-only passing grade.
- Gate: if materials cannot meet privacy/appearance reliably, reject this renderer and present the explicitly permissioned capture alternative. No private blur-radius hacks.

### Phase 3 — Prove region discovery, independently of rendering

- Inventory what the existing no-sensitive-permission window APIs supply. They currently expose whole-window metadata, not message structure.
- Prototype candidate geometry with synthetic moving/scrolled fixtures first; distinguish manually calibrated regions from automatic message detection.
- Exercise sidebar scrolling while arrivals reorder rows, partially clipped rows, archived/search results, changed text size, RTL/multiline content, resized panes, and conversation scrolling with new messages.
- Gate: accepted masks must exclude name/avatar/header/composer regions and cover all currently visible message content after movement. A static grid that eventually drifts fails. Region freshness must be explicit; unknown layouts must not report protected.
- If capture is required to find geometry, request review of its precise capability/data budget first. If Accessibility is the only useful provider, report its sandbox conflict rather than implement it.
- Deliverable: evidence of stable per-item masks on supported layouts. No full product rewrite before both Phases 2 and 3 pass.

### Phase 4 — Architecture change, only after feasibility

Proposed interfaces/files (names may be refined after the prototypes):

- New PrivacyCore/PrivacyRegion.swift: transient region ID, authenticated window/generation, kind (message/preview), bounds, layout epoch and freshness. IDs contain no message text, sender ID or phone number.
- New PrivacyCore/SelectiveBlurPlanner.swift: per-region render/reveal plans; reject stale, invalid or out-of-window geometry; no single whole-window reveal flag.
- New HideWhatsApp/WhatsAppRegionSource.swift: the geometry provider chosen by the evidence. Keep identity authentication in ProcessIdentityProvider; invalidate on generation/layout changes.
- Replace CoverOverlay.swift with a BlurRenderer using only the proven renderer. Preserve normal relative ordering, non-key status, overlay hit-test identification and click-through interaction.
- New PrivacyCore/RegionRevealController.swift: optional per-item reveal; focus/topmost-window checks; immediate reblur on exit, scroll/layout epoch change, focus loss or timeout; freeze reveal when the target identity/geometry is uncertain. No global keyboard/event tap.
- Update Settings/StatusBar/SessionSettings: message blur and preview blur switches, optional per-item reveal; visible states for protected, unsupported layout, stale geometry, paused and permission denied. Do not display 'protected' merely because a process exists or a window is tracked.
- Keep existing build/installer/signing/provenance hardening. For a permissioned route, review CapabilityPolicy.json, CapabilityPolicy.swift and source/binary audits as one explicit capability change; preserve all unrelated negative checks. Never disable audits just to permit a new framework.

Failure behavior must be explicit: no automatic full-window opaque fallback and no silent 'protected' status when messages might be exposed. Report the affected target unsupported/unprotected and stop per-item reveal; retaining stale transparent/material overlays is not proof of privacy. A manual emergency hide could be a separate later feature, not the requested default.

### Phase 5 — Verification and controlled rollout

Behavior tests: preview masks exclude names; content masks exclude header/composer; N rows independently blurred; hovering one item leaves all others blurred; leaving/reordering invalidates reveal; disabled/suspended state reads nothing sensitive; PID reuse cannot inherit a region; invalid/unknown/stale geometry cannot yield protected status.

Visual integration: invented-message fixtures, actual compositing behind separate windows, scroll/resize/zoom/theme changes, frontend click/scroll/type behavior, ordinary menus/modals/calls, multiple WhatsApp windows, Spaces/full screen, multiple monitors/scale factors and fractional coordinates. Validate screenshots manually against the approved appearance; tests that assert 'a window exists' are insufficient.

Security/build: run scripts/test.sh and verified artifact tests, inspect exact entitlements and system-library imports, test signed-policy tampering, retain strict no-network publisher validation, and review no content/network/persistence paths. If capture is approved, test window-only selection, audio/microphone off, buffer lifecycle and denied/revoked consent. Test OS-enforced network denial from an isolated test harness; do not add networking code to the production app just to test it.

Live acceptance is user-operated with harmless chats. First deliver a reviewable PR and a separately identifiable test build; do not silently replace the installed app or enable login launch. Document supported WhatsApp/macOS versions and known gaps before recommending use. Reassess geometry after WhatsApp updates. Independent overlays cannot promise zero-frame privacy, crash-proof concealment or inclusion in all screen-share modes.

## Sources and limits

- Apple, behindWindow: https://developer.apple.com/documentation/appkit/nsvisualeffectview/blendingmode-swift.enum/behindwindow
- Apple, NSVisualEffectView public materials/masking/system-dependent appearance: https://developer.apple.com/documentation/appkit/nsvisualeffectview
- Apple, ScreenCaptureKit capture/permission and single-window content filter: https://developer.apple.com/documentation/screencapturekit/capturing-screen-content-in-macos
- Apple, Core Image Gaussian blur and pixel radius: https://developer.apple.com/documentation/coreimage/cigaussianblur
- Apple, current App Sandbox incompatibilities: https://developer.apple.com/documentation/security/protecting-user-data-with-app-sandbox
- Chrome content scripts (explains the Web references only; not the chosen platform): https://developer.chrome.com/docs/extensions/develop/concepts/content-scripts

These sources establish available API mechanisms and constraints, not successful WhatsApp-specific behavior. No native per-message geometry, unreadability guarantee or permission-free selective renderer has yet been demonstrated. This document is a feasibility plan, not authorization to broaden permissions or a claim that the feature is implemented.

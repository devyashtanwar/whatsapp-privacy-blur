# WhatsApp Desktop selective blur: production integration design

Status: proposed for user review, not implemented. Date: 2026-11-04.

## Intent and approved direction

Bring the accepted synthetic lab's selective Gaussian appearance and per-item hover behavior to the existing native WhatsApp Desktop app through a separate companion. The user accepted the lab appearance and interaction, and explicitly authorized receiving pixels of a WhatsApp window they select. This authorizes planning a narrowly scoped capture path; it does not authorize broad desktop capture, Accessibility, OCR, database access, or automatic installation/permission grants.

The user additionally requires independent control of sidebar message previews, the opened conversation's messages, names and avatars. A conversation-only mode means message content, not the whole conversation pane or window. The tint range is user-specified at 40–90%, initially 65%.

## Current evidence and remaining feasibility gap

Base inspected: b8eea297574faf77c4c2e204288c1a90afe32872, branch codex/selective-blur-feasibility. Production WindowMetadata.swift exposes authenticated whole-window bounds only; CoverOverlay.swift renders opaque rectangles. The lab GaussianMessageView draws invented text it owns; MessageBlurSurface and ScrollAwareClipView share the content's view hierarchy. The companion cannot reuse that hierarchy or receive WhatsApp's local scroll hooks.

Accepted lab visuals do not prove automatic real-message geometry, pixel-to-overlay alignment, external hover events, or synchronized scroll concealment. No full production rollout until these are demonstrated. Capture is necessary for this proposed controlled Gaussian path but is not sufficient to solve geometry or synchronization. No zero-frame guarantee is made for an independent overlay.

## Approaches and decision

1. **Chosen for investigation: user-selected window capture plus local analysis and Gaussian rendering.** Use public ScreenCaptureKit and the system sharing picker; retain App Sandbox and offline operation. Cost: the companion processes private window pixels and must prove both segmentation and external overlay timing.
2. **No-capture system materials.** Limited system-dependent appearance and still no message geometry provider. Does not transfer the accepted controlled Gaussian renderer to WhatsApp.
3. **Accessibility, injection, or modified WhatsApp.** Not selected. Assistive Accessibility conflicts with the sandbox requirement; injection/modification adds unacceptable maintenance/security concerns. No unsandboxed helper or private WindowServer/blur API.

User selected the first direction by approving explicitly selected WhatsApp pixels. Algorithm details, performance tuning and module organization are engineering decisions subject to the gates below.

## Settings and user experience

Provide four independent blur switches and two independent optional message/preview hover switches:

| Control | Affects | Default on an explicit capture session |
| --- | --- | --- |
| Blur sidebar previews | Last-message text, content-bearing attachment/media previews within list rows | On |
| Blur conversation messages | Visible message content and content-bearing media/replies/captions in the opened conversation | On |
| Blur names | Contact/group names in sidebar rows and the opened-conversation header | Off |
| Blur avatars | Profile/group avatars in sidebar rows and the opened-conversation header | Off |
| Reveal hovered sidebar preview | Only the preview under the pointer | Off |
| Reveal hovered conversation message | Only that message's content | Off |
| Blur tint | All enabled categories; 40–90%, initially 65% | 65% |

Both message categories on is a proposed default, not a claim that the user selected that default. Names and avatars remain visible by default and can each be blurred independently, even with both message categories off. The initial identity-blur scope is sidebar rows and the opened-conversation header; sender labels embedded inside message content follow the conversation-message setting. This is not face recognition or anonymization of people appearing in photos/videos. Header controls, navigation, search, composer, timestamps and unread counts remain readable where the validated layout can distinguish them. Names and avatars have no hover-reveal behavior in this version: they stay blurred until their own switch is disabled. Message/preview hover must never clear enabled name/avatar masks. Replies and media require explicit fixture coverage; if the implementation cannot distinguish them safely it reports that layout unsupported rather than claiming partial coverage as complete.

The four message combinations must work: previews only, conversation only, both, and neither. Names and avatars are independent of those choices; all 16 combinations of the four blur switches must work, including names-only and avatars-only. Turning a category off removes its masks and revokes its reveal immediately without clearing any other enabled category's masks. Disabling a message category also disables its corresponding hover control; names and avatars have no hover control. Switching any category back on starts blurred; a message category with hover enabled requires fresh pointer movement to reveal.

The menu-bar popover contains: selected-window status; Choose WhatsApp Window; a Messages section with preview/conversation switches and their hover controls; an Identity section with names/avatars switches; shared appearance slider; Pause/Resume; Stop Window Access; and Privacy Limits. No lab fixture controls, sidebar-width guess, or whole-window reveal toggle in this product flow. Use native controls, readable spacing and compact sections. The accepted localized rounded Gaussian treatment is the visual reference; do not add a new dashboard or heavy decorative chrome.

Settings are session-only in the first version, matching current privacy constraints. Fresh launch is idle with no stream; selecting a window is required each session. No capture at login or automatic reattachment. A changed or relaunched target requires explicit reselection. Pause or all four blur categories disabled stops the stream, releases app-owned frame references and removes masks; resuming requires deliberate action and revalidated consent, using the picker again if necessary. Stop Window Access ends the stream/selection and releases retained references; it does not claim to revoke permissions in macOS Settings.

## Capture and data boundary

- Integration preview minimum is macOS 15.2: SCContentSharingPicker exists on 14, but exact included-window/display/app inspection requires 15.2; see the execution record. Keep the existing cover/lab deployment targets unchanged until a separate integration target is proven. Verify the actual picker-only path on the supported OS; do not silently fall back to blanket Screen Recording access.
- User picks a single window through system UI. Restrict selection to one window; reject display/app/multiple-window filters, unknown scope and non-WhatsApp ownership. Prove that picker metadata permits binding the exact window to the authenticated process before accepting frames. If not possible under these constraints, stop the investigation and report the gap.
- Reuse offline publisher/process-generation checks. A matching title/icon/bundle ID alone is insufficient. Revalidate selection changes, target replacement and PID/window reuse. Never substitute another window silently.
- The selected window's pixels can include names, composer text, media and messages even when only one category is blurred. Blur switches change output coverage, not capture permission or the complete incoming frame. Disclose this plainly; do not claim sidebar-only mode reads only sidebar pixels.
- No network entitlement, telemetry, remote services, file export, chat history, logs of private content, keyboard/clipboard monitoring, audio, microphone, camera, location, Accessibility, database reads or hidden helper. No third-party runtime dependency or downloaded model.
- Initially use local structural image analysis. No OCR, semantic message parsing, recognized strings or model download is authorized. If this cannot supply correct regions, return with evidence and a new decision rather than silently broadening access.
- Keep bounded work: one current frame plus one pending input frame; drop superseded input. Account separately for filter/intermediate GPU memory and establish measured limits before rollout. No recording output or disk frame cache. Release app-owned frames on stop/pause/lock/session loss/selection loss; do not claim forensic zeroization of framework/GPU memory.
- Explicitly disable audio output/capture and camera-dependent effects. Picker/filter changes require validation before processing resumes. Do not log or persist picker metadata, window titles or screen content.
- Preserve hardened runtime, exact entitlements, signed capability policy and source/binary audits. Introduce a narrow, separately verified capture profile first; do not relax the current cover or lab policies to make a prototype build.

## Processing architecture

Selected target -> scoped capture -> local region detector -> validated region snapshot -> Gaussian compositor -> click-through, non-key overlay above the selected target.

Every accepted snapshot binds window identity, process generation, frame sequence, capture timestamp, pixel dimensions, display scale, window transform and region geometry. Ephemeral region IDs contain no content. Never combine geometry from one frame with pixels from another. Hover eligibility also binds the geometry generation; uncertain correspondence cancels reveal. Different messages must not inherit a prior message's reveal because their rectangles overlap.

Reuse GaussianRenderer's filter logic after separating it from invented-text drawing, not GaussianMessageView's string rendering. Render actual selected-window crops flattened opaque before Gaussian filtering, then tint the blurred output. No alpha blend that admits sharp underlying text. Mask edges must cover glyph fringes and avatar edges without hiding disabled categories or controls; identity masks are included only when their own switches are enabled; do not copy the lab's decorative border indiscriminately onto real message previews. Maintain native scale and theme-aware appearance. Tint is an opaque color veil applied over already-blurred pixels, not overlay alpha that admits sharp content. Validate Gaussian unreadability at 40%, 65% and 90%, including the lower-veil 40% case; a wider tint range must not substitute for adequate filtering.

Only the targeted, visible, supported window is eligible. Validate occlusion, window ordering, display/scale changes, Spaces/full screen, dialogs, search/archive lists and target changes. Initial support may be restricted to one ordinary foreground window; unverified modes must explicitly remain unsupported.

## Scroll, hover and failure contract

The lab's 150 ms quiet period and two-second maximum reveal lease are starting behavior parameters. They must be revalidated against external frame delivery, not treated as proof of synchronization. No timer acquires a reveal. Reveal only after actual pointer displacement on a current, stable, topmost target; sampled unchanged coordinates, old queued events, scrolling content passing under a stationary pointer and frame arrival cannot acquire a reveal. Leaving, expiry, focus loss, category change and detected content/layout motion revoke it. Recover without switching windows or visiting an empty area.

No global keyboard/event tap or Accessibility scroll monitor. First prove whether capture-motion observations and current pointer/window metadata suffice. Revocation on observed motion is later than an in-process will-scroll hook; explicitly measure that gap. No unsupported claim of pre-scroll revocation.

Stale pixels, invalid/unknown geometry, capture loss or render failure must revoke hover and change status to Not protected or Unsupported layout. Never show a green protected state based only on stream/window existence. Never draw sharp replacement content or silently substitute a full-window black/grey cover. Retaining old masks is not reliable concealment, and removing them exposes original content: the UI and documentation must state that failed/stopped overlays leave WhatsApp visible. This is visual concealment, not a lock.

Two release gates are independent: (1) measured geometry/content coverage and (2) real user acceptance of scroll/interaction timing and appearance. If external overlays cannot satisfy the accepted no-visible-disclosure behavior, do not promote this implementation as production-ready; report that limitation rather than adding a cosmetic patch or weakening access restrictions.

## Acceptance and delivery

Use invented external-window fixtures before user-operated harmless WhatsApp chats. Cover all 16 blur combinations and applicable message/preview hover combinations, names-only/avatars-only mode, identity-mask persistence during message hover, partially clipped sidebar rows, new-message row reordering, chat switches, multiline/RTL/emoji/link content, replies/media, rapid momentum scrolling, resizing, theme/scale changes and focus/occlusion. Include dropped/out-of-order frames, denied/cancelled/revoked access, frozen streams, target identity changes and unsupported layouts.

Record frame-age/alignment/performance measurements without content. Automated tests prove contracts; they do not certify human unreadability or zero-frame privacy. User runs all visible UI, system picker and WhatsApp acceptance tests; agent does not operate the desktop, install/launch the app or grant permissions.

Deliver a separately identifiable integration preview and reviewable PR. Retain the tested lab as a regression reference. Production promotion happens only after capability review, signed-bundle verification, geometry/timing gates and user acceptance. Do not merge or replace the installed app automatically.

## Revision record

User amendment: tint range widened to 40–90% with the initial value unchanged at 65%; optional independent Gaussian blur for names and avatars added, both off by default. Capture lifetime, settings tests, geometry exclusions and hover isolation now account for all four categories. This amendment is documentation only and has been self-reviewed; the earlier independent review predates these additions.

## Primary references checked in this conversation

- System picker, macOS 14+: https://developer.apple.com/documentation/screencapturekit/sccontentsharingpicker
- Single-window filter: https://developer.apple.com/documentation/screencapturekit/sccontentfilter/init(desktopindependentwindow:)
- Picker/stream lifecycle: https://developer.apple.com/videos/play/wwdc2023/10136/
- Sandbox incompatibilities: https://developer.apple.com/documentation/security/protecting-user-data-with-app-sandbox
- Material appearance differs from controlled Gaussian filtering: https://developer.apple.com/documentation/appkit/nsvisualeffectview

These sources describe APIs, not successful WhatsApp-specific segmentation, consent scope enforcement or scroll privacy. Those remain experiments with explicit stop conditions.

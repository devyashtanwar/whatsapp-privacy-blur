# Automatic WhatsApp Desktop blur: proposed revised design

Status: for user review; no implementation authorized by this document alone. Base inspected:7bd03de8518b8600a96450fedcb25e75fa3a9ba9. This replaces the manual-session/foreground-only assumptions of the earlier Desktop integration design only after design approval.

## Requested outcome and approved boundaries

When automatic blur is enabled, starting this app should attach to an already-running native WhatsApp without a picker. If WhatsApp starts later, attachment follows its authenticated process/window discovery. Relaunching WhatsApp or creating/replacing a supported window must not require selection again. Closing settings must not turn privacy off. Retain independent previews/messages/names/avatars, message-only hover and tint40–90%, default65%.

The user expressly approved **planning automatic mode with macOS Screen Recording permission** and **remembering only blur preferences in private local storage**. They previously approved transient local OCR. These are design permissions, not an OS permission grant and not permission for the agent to operate the desktop. No network, telemetry, content persistence, microphone/audio, camera, location, Accessibility, keyboard/clipboard monitoring, personal-file/database access, private APIs, modified WhatsApp, hidden helper or model download. Preserve sandbox and hardened runtime. Root cover/lab capability profiles remain unchanged.

## Current evidence: distinguish defects from hypotheses

The latest screenshot shows the exact pre-picker status and a disabled Choose button. In the source this means selection is pending; it does not establish accepted selection, capture failure or renderer failure. The selection phase has no running watchdog: the capture watchdog is installed only after a filter is accepted, and CaptureSession.tick ignores selecting. Therefore a missing/ignored callback can leave the app stuck indefinitely. Observer method signatures match the installed SDK; the actual callback delivery/token path on the user's Mac is unknown.

Separate confirmed design mismatches: IntegrationCoordinator.tick/visible require WhatsApp foreground; any above-window intersection withdraws the entire image. In the supplied scene another app is active and settings overlaps WhatsApp. Even a functioning stream can consequently leave visible sidebar content unblurred. Moving/resizing stops the session, no startup process monitor exists, launch activates settings, settings-close stops capture, and preferences reset on quit. These contradict automatic always-enabled behaviour.

Earlier443 generated assertions and successful builds do not establish these live paths. Stop iterating on isolated fixes as proof that the product works. The next candidate needs one integrated lifecycle/rendering harness and explicit native acceptance.

## Approaches and recommendation

1. **Recommended and selected for planning: permission-backed automatic exact-window capture.** Use Screen Recording authorization, app/process monitoring and SCShareableContent metadata discovery; instantiate SCContentFilter(desktopIndependentWindow:) only after offline WhatsApp authentication. No picker in the normal path. The OS permission is broader than WhatsApp; WhatsApp-only restriction is enforced by our code/audits, not a WhatsApp-only OS grant.
2. Picker-scoped capture retains narrower system-selected scope but requires selection when consent/target/session is lost; it cannot fulfill this requested automatic lifecycle under the approved current APIs. Retain only as optional diagnostic/legacy tooling, never silently fall back to it or expand capture.
3. Injection, Accessibility or replacing native WhatsApp with Web are outside the chosen requirements. No such fallback is authorized.

Apple's sample documents Screen Recording authorization and programmatic window filtering. Public API documentation does not promise indefinite permission retention, cross-process overlay ordering or zero-time protection. Permission revocation, rebuilds, signing changes and OS policy can require consent again.

## Permission, identity and discovery

Use a distinctly identified automatic beta evolved from Experiments/DesktopIntegration (new bundle ID devyashtanwar.whatsapp-blur-auto-beta, minimum macOS15.2). Preserve the old cover/lab and archived manual build rules; do not silently turn their existing grants into broad authorization. First setup explains the OS permission, obtains it only on explicit user action, then enables automatic mode. Once permission and the saved Enabled preference are present, subsequent launch has no capture-selection UI. Denied/revoked permission produces Needs Permission, without repeated prompts or display-capture fallback.

On startup, enumerate NSWorkspace.runningApplications and subscribe through NSWorkspace.shared.notificationCenter to launches, exits and activations; reconcile after wake/session activation. Authenticate only net.whatsapp.WhatsApp with the existing offline publisher validator and process generation checks. Bundle ID/title/icon alone never establishes trust. Enumerate SCShareableContent metadata only when eligible discovery is needed, ignore titles and non-target window/app details, and immediately discard unrelated metadata. Read no other-app pixels.

Discovery coalesces duplicate events100ms; after launch with no window, retry at100/250/500ms, then at most once per second while the authenticated app exists. No catalog polling when WhatsApp is absent. Permission/security failures do not trigger capture retry loops. Window/process generation changes create new tokens and revoke old results/reveals. Bind every stream to exactly one freshly resolved authenticated window; never restore a saved PID/window ID.

Each supported visible chat window needs its own bound context; initial acceptance covers one and two concurrent ordinary chat windows. A measured global resource limit must be implemented before enabling multiple streams. Additional/unsupported windows or exhausted budget must produce explicit partial/not-active status rather than a whole-app protection claim. Calls/dialogs are not silently classified as chats.

## Lifecycle and preferences

Persist only schemaVersion, automaticEnabled, four category booleans, two hover booleans and tint in the app's own container. No captured content, OCR, names/titles, identifiers, capture history or diagnostic history. Validate types/finite values; clamp tint; atomic writes; no user-selectable paths or filesystem entitlement. Invalid configuration disables automatic capture and shows a recoverable settings error; do not infer consent from a corrupt file. Defaults remain both message categories on, identities/hover off, tint65%; automatic starts only after first explicit enablement.

Runtime states: Disabled, NeedsPermission, WaitingForWhatsApp, Discovering, Authenticating, Starting, Analyzing, Rendering, Partial, Unsupported, Recovering, Error. Rendering means actual currently installed processed pixels, never stream existence. Per-window state aggregates honestly. This remains experimental until coverage/visibility acceptance; do not use a general Protected label.

Launch does not activate/show settings or steal focus. Closing settings hides them; explicit Pause disables capture and persists that choice. Resume rechecks permission and authenticated targets without a picker. Quit stops capture but preserves Enabled for the next explicit app launch. Login launch is not requested. Sleep/lock/session loss stops/releases streams; enabled mode reconciles on return after permission/identity revalidation. Stream-fault retries are bounded250/500/1000ms; persistent errors become actionable state. Stop/permission/security errors are not auto-retried as transient faults.

Resize/move/scale/Spaces changes invalidate geometry and hover, then reconfigure/rebind under the already-approved automatic mode instead of requiring selection. No old image/mask is published under a new transform. Actual OS support must be proved; unsupported transitions cannot appear active.

## Visibility and rendering feasibility gate

Blur must cover visible supported WhatsApp regions even when another app or this app's settings is active. Hover remains restricted to a deliberately moved pointer over a current exposed item while WhatsApp is active. A settings window over the conversation must not disable blur on the exposed sidebar.

Engineering choice: visibility proof uses a separately built, renderer-only two-process fixture with invented source images. It must never introduce a fixture publisher/identity exception, test mode, resource or module into the shipped beta. Agent may build it; user operates it. Before implementation depends on it, prove public NSWindow relative ordering at the target's normal window level against that external fixture. Do not keep the current normal+1 global overlay or paint WhatsApp pixels above unrelated apps. Where necessary, clip to exposed target portions using metadata-only occlusion geometry; full occlusion removes that surface, partial occlusion preserves exposed blur. Metadata polling and independent windows have races; their real ordering/alignment must pass acceptance. If public ordering cannot safely deliver this behaviour, stop this design's promotion and return with evidence—no private WindowServer API or hidden helper.

Keep processed pixels and their geometry coherent. Audit the full-window processed mirror: stale visible controls plus click-through can misdirect input. It is not acceptable to call a frozen screenshot a smooth native feature. Measure this risk before committing to the existing presentation approach. No sharp-source blend, unrelated pixels, stale reveal borrowing, fixed row grids or opaque pane/window cover fallback.

## Performance and evidence

Proposed engineering gates, not established capabilities: no-input process/window detection after OS notification within250ms; first processed presentation within1s of a capturable window and established permission; steady source-to-display age p95<=100ms and no displayed frame beyond250ms while content is changing, with a30fps target. Measure at normal and Retina sizes on the user's hardware with harmless content; record only timing/counter/own-resource metrics. Startup grant/wait/restart time is excluded and must remain visible, not hidden in the metric.

Profile main-thread sample handling, repeated trust work, image copying, OCR and per-region software Gaussian filtering separately. Move heavy work off the main thread, reuse a hardware Core Image context with the same opaque Gaussian contract, process newest frames with bounded memory, and avoid unnecessary repeated work only when current-frame evidence proves it safe. Never reuse stale geometry during scroll to manufacture frame rate. If OCR/mirror architecture cannot meet privacy and interaction gates, report that instead of shipping another claim based on fixture-only tests. Establish explicit global CPU/pixel/GPU budgets from measurement before multiwindow enablement.

A companion cannot protect WhatsApp while it is not running, retroactively conceal previously visible data, or guarantee intercepting WhatsApp's first paint. Detection/capture/analysis have nonzero latency. Crash, revocation and failed/withdrawn overlays expose original WhatsApp. No zero-frame, zero-latency, always-secured or screen-sharing guarantee. These limits must stay explicit despite automatic attachment.

## Sources and approval state

- https://developer.apple.com/documentation/screencapturekit/capturing-screen-content-in-macos
- https://developer.apple.com/documentation/screencapturekit/sccontentfilter/init(desktopindependentwindow:)
- https://developer.apple.com/documentation/screencapturekit/sccontentsharingpickerobserver
- https://developer.apple.com/documentation/appkit/nsworkspace/didlaunchapplicationnotification
- https://developer.apple.com/documentation/appkit/nswindow/order(_:relativeto:)

User approved the permission/persistence choices for planning. This full design and its implementation plan still require review before runtime changes. Agent remains CLI/read-only/hidden-generated-test only; user operates OS permissions and live acceptance. No automatic installation, launch, merge or OS-setting changes.

Planning review: a fresh macOS builder check reported “nothing important left.” This is a design completeness check, not proof of OS behaviour or production safety. No runtime tests/builds or permission changes were performed for these documents.

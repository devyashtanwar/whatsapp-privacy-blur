# Native Desktop test candidate — 2026-11-12

This phase connects the separate app to explicitly selected WhatsApp pixels. It is no longer an access-only checkpoint or an invented-message demo. It is **not a production/privacy certification**. The root solid-cover target remains separate and unchanged; Gates B/C and real native acceptance remain incomplete.

## Authorization and implementation

The user requested a manually testable native app with all four independent blur categories, two message-only hover controls and 40–90% tint initially 65%. They explicitly answered “Allow local OCR in the test app” after the earlier investigation-only consent. This permits transient OCR during use of the selected window, not content persistence, networking, broader capture, Accessibility or an extra permission.

The existing exact-window picker, offline publisher authentication, process generation/window ownership checks, hardened runtime, strict startup validation and sandbox-only entitlement remain. Capture now continues until Stop/close/all-off/session loss/target failure; complete and idle callbacks maintain a bounded current session. Configuration excludes audio, microphone, child windows, window shadow, cursor and image scaling. A changed window position or size requires a new explicit selection.

Vision OCR returns bounding boxes and whitelisted enum labels; recognized strings stay in the synchronous request. A persistent vertical image divider plus Search/composer anchors bounds an experimental layout. Sidebar pairs come from observed baselines, not an invented row grid. Conversation text/rectangle observations provide candidate message/media regions. Names and avatar bounds are independently categorized. This is heuristic evidence, never `supportedLayout`.

The compositor reuses the accepted Gaussian filter source through the immutable snapshot. It constructs a single opaque processed image: unchanged UI outside selected regions, Gaussian-filtered/tinted pixels inside them. This avoids asynchronous separate patches lagging behind pixels **within that image**. Local corner sampling follows bubble colours instead of a white/black tint block. No sharp source is blended under the tint. Enabled identity masks are applied after message regions and cannot be removed by message hover.

One serial worker serves analysis/composition/reveal, with one newest pending captured frame. Completed results must match the settings/stop revision, monotonically newer publication, current target bounds, foreground state and a one-second receipt budget. An authenticated idle callback attests unchanged selected-window content and refreshes the latest complete frame's receipt time. A stopped or changed session cannot publish a late result. Stop clears queued/display references; an already-running synchronous request can finish before releasing its input, and its result is discarded.

New complete frames revoke hover before analysis, restoring the last fully blurred processed image. Pointer movement after 150 ms quiet can acquire at most one two-second message/preview lease. Timer/frame arrival cannot acquire reveal; names/avatars are never eligible. Results of asynchronous reveal filtering must still match revision/frame/activity and lease before display. Focus loss/occlusion removes the external image; metadata checks consume IDs, bounds and alpha of windows above the selected target, not their titles/pixels.

## Known acceptance gaps and deliberate limits

- This detector has not seen an agent-captured real WhatsApp frame. No desktop/browser/app was operated by the agent. Existing open-conversation reference images were Web examples, not native ground truth.
- English Search and empty composer placeholders plus an unambiguous divider are required. Typing, localized/changed layouts or ambiguous boundaries can make detection unavailable.
- Text/rectangle detection does not prove complete media/bubble coverage. Row pairing, sender-name classification and inferred avatar bounds can be wrong; partial rows/RTL/replies/emoji/theme variations remain unverified.
- Failure or lost visibility withdraws the image and exposes original WhatsApp. This is explicitly disclosed in UI/guide. There is no emergency pane/window cover, protected status or zero-frame guarantee.
- Full-frame processing can visibly lag/freeze while scrolling. Clicks pass through to live WhatsApp, so a delayed displayed control can differ from the actual click target; use harmless self/test chats and do not send sensitive content. Publishing coherent pixels/masks is not proof of smooth native interaction. Animating UI can repeatedly revoke hover.
- External ordering, frame-to-screen alignment, moving/resizing, Spaces/full screen/multiple displays, permission revocation and screen/window sharing need user-operated acceptance. Do not infer these from unit tests.
- The app receives all selected-window pixels even in sidebar-only mode. System caches and the app's bundled policy/signature reads are separate from application content saving; no forensic erasure claim is made.

The test candidate must use harmless chats. A successful build or detector count is never a claim that all requested content is obscured. Production promotion remains a separate decision after real native coverage, interaction and security acceptance.

## Regression evidence

See the execution ledger/test logs for exact runs. Test-first failures observed in this phase: compositor scaffold 22 failures, external hover 3, continuous-session 1, publication gate 7, anchored layout 1, explicit experimental render 1, local bubble tint 2; the signed Network load-command mutation was accepted before adding the framework rejection. The mutation never executes the altered bundle.

Generated-image probes and pixel tests are not real WhatsApp support evidence. Final test/build/review results are appended after verification below.

## Review boundaries and deferred details

A fresh read-only review found no Critical issue and three Important issues: delayed first pointer sampling could invent movement, observed occlusion could preserve an old reveal/completion, and presentation needed full process-generation/session binding validation. These require a test-first fix pass before handoff; final results are recorded below.

The reviewer did not certify real native OCR/media/identity completeness, clipped/RTL/reply coverage, blur unreadability, scroll quality/alignment, permission/revocation, Spaces/full-screen/displays, actual window-server ordering/sharing, or measured Vision/GPU memory/latency. These require user operation and measurement. Neither source review nor synthetic tests promote the app to privacy protection.

Deferred minor details: the displayed status can lag an overlay withdrawal; settings changes withdraw the complete image while recomputing, temporarily exposing all original content; and historical checkpoint comments/error wording remain. The visible UI never claims protected coverage. Existing deferred provenance limitation (concurrent checkout revision labelling) and the earlier composer-count/media-observation test limitations also remain. Test with harmless chats and do not rely on privacy during settings/focus/visibility transitions.

## Final local verification — 2026-11-13

All three Important review findings were reproduced by ten failed generated assertions, then corrected. First pointer observation is baseline-only, including delayed sampling after selection/settings/focus; visibility interruption revokes the lease and its completion revision; presentation revalidates the full active selection token, window/PID/process generation, original process continuity and current ownership/bounds, stopping the current session on a mismatch. Independent generation and continuity negatives were also added.

Final runs: **295 integration assertions, 10 actual capture-configuration assertions, 16 generated OCR/layout assertions and 107 compositor pixel assertions passed**. The final signed native candidate built and verified its exact sandbox-only grants, hardened runtime, startup/manifest pins and restricted linked APIs. The complete repository suite passed **79 Python tests, with three explicit authentic-signature/live-process fixture skips**, alongside the existing core tests and signed cover/lab/candidate rejection checks. The re-signed Network-load-command fixture is rejected; the modified fixture is never executed.

No GUI, WhatsApp inspection, real captured private-frame processing, installation or app launch was performed by the agent. Native coverage, perceived appearance, performance and interaction acceptance remain unverified. This is a manually testable native candidate, not production promotion or privacy certification. Deferred details above remain.

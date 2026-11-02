# Runtime capability audit

This inventory covers the executable and its source at this PR. The app places opaque local covers; it does not process chat text or pixels.

| Runtime component | Inputs/purpose | Retention and capability boundary |
| --- | --- | --- |
| main/AppDelegate | AppKit lifecycle; own confinement check before monitor creation | No target metadata before successful gate; invalid/raw/unconfined launch terminates locally |
| RuntimeConfinement | Own running-code validity, corresponding static signature, signed local policy resource | Security framework calls only; strict validation explicitly disables network-dependent work; no shell/codesign process |
| CapabilityPolicy | Exact app ID, signature/runtime facts, boolean sandbox entitlement, fixed policy document | Pure validation; rejects every additional entitlement and altered/missing policy |
| SessionSettings/Settings | Enabled/full-window/hover/manual-width session choices | In-memory only; no UserDefaults, logs or preference writes |
| ProcessIdentity/ProcessTrust | Candidate PID, bundle ID, launch generation, running-code signing requirement | In-memory generation-bound positive/negative cache; lifecycle invalidation; no secret Keychain APIs |
| WindowMetadata | Authenticated live target PIDs; window ownership/geometry; display coordinate origin | No window-title/chat-text access; no snapshots if no authenticated target; no pixel capture |
| HoverSampling | Pointer location and hit window, only when explicitly enabled | Lazy reads; disabled/suspended monitoring never calls source; hover-off never calls cursor/hit providers |
| PrivacyCore | Coverage geometry and trusted foreground decisions | Pure calculations; finite/clamped rectangles; no network/files/devices |
| PrivacyMonitor | Workspace/settings/display lifecycle; one timer | Clears covers/stops polling when disabled/suspended; no global input tap |
| CoverOverlay | Approved frame/reveal plans | Opaque NSWindows; mouse events pass through only when revealed; no images or captures |
| StatusBar | User menu actions and local status/errors | No URL/file dialogs, sharing, browser, printing, or remote help routes |
| LaunchAtLogin | Explicit user toggle of SMAppService | Local OS registration only, off by default; no custom helper, permission expansion or covert persistence |

## Enforced artifact policy
The app must have exactly the boolean com.apple.security.app-sandbox entitlement. No outbound/inbound networking, personal-data/device/file-access, app-group, automation or temporary exception entitlement is permitted. Hardened runtime and a valid sealed signature are mandatory.

Only the main executable, Info.plist, the two approved JSON resources and the signature envelope may be shipped. Extra helpers/extensions/resources are rejected. Source guardrails reject known egress/broker/device/persistence APIs, external package/plugin/unsafe-flag additions and network-assisted certificate trust. Binary checks reject sensitive direct imports and non-system dynamic libraries.

These scans are regression guardrails, not a proof against arbitrary obfuscated code or future altered tools. The startup gate is defense in depth; the OS sandbox is the direct capability restriction.

## Target publisher identity
The target requirement is Apple-anchored code with identifier net.whatsapp.WhatsApp and certificate leaf OU 57T9237FN3. Both the identifier and TeamIdentifier were observed in the installed target metadata. The metadata alone is not trusted: the running target must satisfy the full requirement.

Strict Apple-anchor validation of the installed sample failed in this execution environment (including the read-only elevated check); no trustworthy certificate chain could be extracted from that sample. It is deliberately not accepted as an authenticated fixture. This PR never relaxes the anchor or allows a matching identifier/TeamIdentifier alone. An authenticated official-distribution fixture and real sandbox process validation remain required before personal use; unsupported/re-signed targets produce an untrusted-target status and no covers.

## Offline scope
No runtime network client/server/update/telemetry code or sensitive-data prompts are implemented. The same applies to indirect browser/URL/web-view/sharing/shell routes. No dependency downloads are needed. Default ad-hoc signing does not request an online timestamp.

Optional Developer ID signing can explicitly request a publisher timestamp during a build; build/CI traffic is separate from app runtime. Necessary local OS IPC, executable/framework/resource reads, OS-managed containers/diagnostics and explicit opt-in login registration remain platform behavior. This is not a promise of zero filesystem or all-system network activity. The separate WhatsApp app keeps its own networking.

## Offline certificate tradeoff
All running-code/static-code validity checks supply the explicit no-network flag. This prevents network-dependent certificate work but cannot retrieve fresh online revocation/notarization status; offline trust is not live revocation assurance. No system-wide trust or network settings are changed.

## Evidence limits
Synthetic policy/adapter-boundary checks, real temporary filesystem races and static signed-artifact rejection tests do not certify live window ordering, sandbox metadata/code-identity access, ordinary screen lock, login behavior, or actual runtime network silence. No GUI app launch, installation, permission grant or WhatsApp-content access is performed by this PR's implementation.

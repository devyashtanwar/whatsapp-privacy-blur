# Second security pass — findings and implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task after the user's review. Steps use checkbox syntax. This document is a plan, not an implementation record.

**Goal:** Close the newly identified installation, process-identity and provenance gaps, and enforce a strictly offline, minimal-capability app whose sole runtime purpose is local visual concealment.

**Architecture:** Preserve opaque covers and pure coverage policy. Add a shared capability policy enforced by source review, signed-artifact checks and a startup gate. Harden filesystem publication, authenticate target processes, and compile a fixed source snapshot. Do not add services or permissions to compensate for unsupported OS behavior.

**Tech Stack:** Swift 5.9+, AppKit/CoreGraphics/Security, Python standard library, Darwin filesystem primitives, existing CLI test harness and macOS CI. No third-party runtime packages.

**Spec:** Existing [privacy-hardening design](../specs/2026-11-02-privacy-hardening-design.md), with the threat-boundary refinements and acceptance criteria below.

**Status:** Implementation authorized and source changes completed on codex/offline-security-boundary, based on merged main 14e12c6. See docs/security-execution.md and docs/runtime-capability-audit.md for test evidence and remaining live acceptance. Historical findings below describe the pre-implementation review.

**User-directed scope extension:** The user requires offline operation and rejection of unrelated capabilities, including internet, microphone, location and personal-file access. The requirements below supersede weaker defaults elsewhere in the earlier design.

## Reviewed state and method

Checked GitHub on 2 November 2026:
- main remains original upstream commit da50ac5d4817d6098d984f9312e73b1f6c38ca05.
- PR #1 is open/unmerged at 70059b348e4c9f16581fb555935799fd9a92887d.
- Local HEAD matches that PR. Its Git tree is 4eee3fad295269f15b3e770863c7af4fb348a2dc.
- Complete remote recursive tree was non-truncated; all 32 tracked files were accounted for.

This pass reviewed all application code, core policy, settings/login behavior, installer, build/signing verifier, tests, CI and documentation. It used skeptical control-flow review, a fresh read-only reviewer's observations, targeted temporary-file probes, and a fresh baseline test run. Previous review conclusions were not treated as proof.

Baseline rerun: 11 core tests / 30 assertions / 0 failures; 9 installer tests / 0 failures. Local developer search-path warnings remain non-fatal.

No app UI, browser, actual WhatsApp data, app installation, permission grant or app launch was used. The probes operated only on synthetic temporary fixtures; successful platform validation was injected for installer fixtures, and compiler/signing boundaries were stubbed for the provenance probe.

No intentional exfiltration, telemetry or direct remote execution path was found in this source. This is not an exhaustive security certification.

## Threat model

Distinguish:
1. Remote chat content / network attackers: no new path from chat contents to code execution or app-owned networking was identified.
2. Local operational hazards: simultaneous builds/installers, source edits during compilation, and filesystem aliases can cause unexpected replacement or misleading artifacts.
3. An already-running local impostor app: bundle ID strings are insufficient identity. The relevant privacy consequence is induced visual disclosure with opt-in hover, not proof that the cover reads or uploads chats.
4. A fully malicious same-user process that can edit this repository/toolchain: out of scope for complete containment. The changes must not claim protection against arbitrary tampering by that account or the OS.

## Mandatory offline and minimal-capability policy

### Current code analysis

Rechecked Sources, Package.swift, Info.plist, PrivacyCover.entitlements, signing/build scripts and the verifier when adding this requirement:
- No HTTP client, socket/listener, web view, remote URL opener, analytics, updater or network dependency is implemented in the runtime app.
- No microphone, camera, location, contacts/calendar/photo-library, Bluetooth/USB, clipboard, Keychain-secret or user-document API use was found.
- No Accessibility, Screen Recording, keystroke monitor or shell execution is implemented in the runtime app.
- The current signed-entitlement allowlist is exactly {"com.apple.security.app-sandbox": true}. Missing network/client, network/server and sensitive-resource grants already restrict direct capability use, but source absence alone is not an enforcement proof.
- The runtime currently reads window/process metadata and cursor/hit-test state, writes its own UserDefaults preferences, and offers opt-in SMAppService login registration. These are explicit local activities, not internet requests.
- The current static verifier has only a limited direct-import denylist and no dedicated device-access, broker-route or unsigned-launch regression coverage. The raw Swift executable can bypass the signed-bundle configuration; the new startup gate must reject that operating mode.

### Runtime capability budget

| Capability | Required policy |
| --- | --- |
| Internet/outbound connections | Denied: no HTTP(S), WebSocket, DNS discovery, TCP/UDP/QUIC connections, remote assets, uploads, telemetry, crash uploads or update checks. No network-client entitlement. |
| Inbound/local servers | Denied: no app-owned listening TCP/UDP endpoints, localhost control servers, remote commands or network-server entitlement. |
| Indirect network routes | No opening remote/custom URLs in browsers or other apps; no web views, sharing/upload services, Apple Events, shell helpers or URL/file handlers that provide another route to transmit data. Do not claim that a missing socket entitlement alone closes these broker routes. |
| Microphone/camera | No capture APIs, permission requests, usage descriptions or device entitlements. |
| Location | No location framework/service requests, permission prompts, usage descriptions or entitlement. |
| Personal files/data | No reads/writes to Documents, Desktop, Downloads, external volumes, other app containers, browser profiles, WhatsApp databases, contacts, calendars, photos, reminders or secrets. No file chooser, drag/drop import, security-scoped bookmarks, broad file entitlement, shared app group or temporary sandbox exception. |
| Screen/Accessibility/input | No screen pixels, Screen Recording, Accessibility, Input Monitoring, keyboard recording or clipboard access. |
| Other devices | No Bluetooth, USB, serial, printing or other unrelated device integrations/entitlements. |
| Window placement | Allow only authenticated target-process identity, required on-screen ownership/geometry, display coordinates and lifecycle notifications. Never read chat text/window titles or persist window metadata. |
| Cursor/hit-testing | Allow only while the user explicitly enables hover reveal and monitoring is active. Stop these reads when disabled, suspended or hover is off. |
| Preferences/logging | Use session-only settings by default under this stricter requirement. Remove deliberate preference-file persistence and content/metadata logs, caches, histories and crash-upload SDKs. Settings reset after restart; disclose this behavior. |
| Login service | Existing opt-in local login registration may remain off by default. It must not grant unrelated capabilities or create a custom helper/service. This is an OS setting, not covert persistence. |

The signed app must require no sensitive-data permission prompt in normal use. Permission denial/revocation must never trigger instructions to grant broad access, open System Settings, remove the sandbox, disable OS protections or launch an unsandboxed fallback.

### Accurate enforcement boundaries

- App Sandbox must remain enabled, with the exact signed entitlement allowlist containing only its sandbox flag. Reject every extra entitlement, including network, device, personal-information, file-access, automation, app-group and temporary-exception grants.
- Absence of a grant is different from an explicit macOS restriction on every possible action. Combine OS confinement with eliminating unused code and validating all shipped executables/resources. Do not rely on a framework/symbol denylist as a malware-proof boundary.
- macOS necessarily reads the executable, system frameworks and app resources and may maintain an app container, preferences, diagnostics and OS bookkeeping. Standard App Sandbox does not provide a truthful "zero filesystem access of any kind" guarantee. The requirement is no personal-file access and no deliberate app-created data persistence beyond unavoidable OS behavior, with remaining platform allowances documented.
- Necessary local OS IPC for window metadata, signing validation and the menu bar is permitted; no application-defined control server or generic IPC bridge is permitted.
- These restrictions apply to the cover app and anything it ships or launches. They do not disable the separate WhatsApp app's own network connection or change the Mac's global networking/privacy settings.
- Clone/build/CI/publisher signing traffic is separate from runtime behavior. Keep the default build local with existing toolchains, no third-party downloads and ad-hoc signing without timestamp requests. Any optional Developer ID timestamp/notarization network operation must be explicit and documented; never perform it at app startup.
- A future modified/unsigned program or a fully compromised OS is not bound by this source policy. Do not promise permanent impossibility of access across arbitrary future builds.

## Findings

### F1 — P2: no-replace installation can replace a destination created during staging

Evidence: [install_bundle.py lines 24–40](https://github.com/devyashtanwar/whatsapp-privacy-blur/blob/70059b348e4c9f16581fb555935799fd9a92887d/scripts/install_bundle.py#L24).

The initial destination-exists check rejects an existing installation unless replace=True. After copying/validating, the code checks destination existence again and backs it up unconditionally, without rechecking replace. A second installer or other process can create the destination during that interval; the first operation silently replaces it despite replace=False.

Temporary-fixture reproduction: a validator created a destination after the initial check. install_bundle(..., replace=False) returned successfully, created a backup and replaced the new destination with the candidate. Output: replacement_without_opt_in=true, backup_created=true.

Impact: broken replacement-consent invariant and races between legitimate installer/build processes. No remote attacker or privilege escalation demonstrated.

### F2 — P2: lexical path checks allow parent aliases and build-output redirection

Evidence: [install_bundle.py lines 13–32](https://github.com/devyashtanwar/whatsapp-privacy-blur/blob/70059b348e4c9f16581fb555935799fd9a92887d/scripts/install_bundle.py#L13), [build_app.py lines 45–49](https://github.com/devyashtanwar/whatsapp-privacy-blur/blob/70059b348e4c9f16581fb555935799fd9a92887d/scripts/build_app.py#L45).

Path.absolute() does not resolve parent symlinks. Checking only the destination leaf for a symlink and comparing lexical parents does not establish physical separation.

Two consequences:
- An aliased destination physically inside the source passes the ancestry check. Staging then occurs inside the source, so copytree can recursively copy its own staging directory. A fresh reviewer demonstrated the accepted descendant using an intercepted copy operation, stopping before recursive disk consumption.
- If repo/dist is a symlink to another directory, the build-only command follows it, replaces an existing app at that location, then deletes the returned backup. This contradicts the promise that build output cannot alter an installed application.

Temporary-fixture reproduction of the second case: repo/dist pointed to a synthetic Applications directory. Publication overwrote its old app, and the cleanup matching build_app.py removed the backup. Output: outside_destination_overwritten=true, old_backup_removed=true. No actual installed app was touched.

Impact: local unintended writes/deletion or excessive recursive copying under alias conditions. This is a correctness and confinement defect, not proof of a sandbox escape.

### F3 — P2 privacy hardening: a matching bundle ID is accepted as WhatsApp identity

Evidence: [WindowMetadata.swift lines 10–17 and 26](https://github.com/devyashtanwar/whatsapp-privacy-blur/blob/70059b348e4c9f16581fb555935799fd9a92887d/Sources/HideWhatsApp/WindowMetadata.swift#L10).

Both process selection and the foreground check use only the bundleIdentifier string. An unrelated local app can declare the same identifier. With hover reveal enabled, a foreground impostor can satisfy targetIsFrontmost while the cursor is over an authentic background WhatsApp window; the core has no authenticated identity information to reject that state.

Established from source: the identity predicate is string-only, and the resulting boolean permits the reveal branch. No impostor app was installed/launched and the live activation sequence was not exercised.

Impact and prerequisites: a local impostor process, opt-in hover enabled, and the relevant pointer/window state. This does not show automatic data theft, a root compromise or a remote exploit. It weakens the advertised foreground-only reveal condition and can mask/track unrelated same-ID windows.

### F4 — P2 audit-integrity issue: the recorded source can differ from the compiled source

Evidence: [build_app.py lines 20–39](https://github.com/devyashtanwar/whatsapp-privacy-blur/blob/70059b348e4c9f16581fb555935799fd9a92887d/scripts/build_app.py#L20).

Compilation happens before the build hashes live source files. An editor changing a file after compilation but before hashing can make source-manifest.json attribute different bytes to the executable. Signing the final bundle seals that inaccurate attribution; it does not establish the missing input relationship.

Controlled pipeline reproduction: the compiler boundary left a fixture executable representing ORIGINAL bytes, then changed the source before manifest collection. The output manifest recorded CHANGED-AFTER-COMPILATION while the artifact retained ORIGINAL. Compiler, signing and validation tools were stubbed; this proves the pipeline ordering flaw, not a cryptographic bypass or an actual malicious build.

Impact: unreliable source-to-artifact audit evidence during concurrent edits. Current docs already disclaim reproducible builds, but describing the manifest as exact compiler inputs is still too strong.

## Acceptance gaps and lower-priority observations

These are not additional proven exploits:

- Only layer-zero target windows are decoded, while covers have normal window level. Whether actual supported WhatsApp chat/pop-out/call surfaces use other levels must be inventoried on the real OS/app version. Do not blindly cover every nonzero layer: menus/tooltips and unrelated transient surfaces need deliberate scope.
- Cross-process relative ordering, pointer hit-testing and Spaces/fullscreen behavior have not been tested with real AppKit windows.
- Ordinary screen locking has no dedicated verified handler; display sleep and session switching are different conditions.
- The app currently reads cursor position/hit window even when hover reveal is disabled. Skipping those reads is optional data minimization, not a fix for observed exfiltration.
- Test coverage is concentrated on the pure core and installer fixtures. Signature-verifier rejection behavior, process authentication and the real monitoring adapter are not exercised by the 20-test baseline.
- Static symbol checks are explicitly guardrails, not a malware detector. Ad-hoc signing is not publisher authentication/notarization.
- Source dictionaries can carry coercible numeric values; tighter integer/type/geometry boundary checks are useful defense in depth, but no reachable remote input path or actual OS metadata exploit was established.
- Crash/quit exposure, capture modes excluding overlay windows, and short polling gaps remain inherent documented visual-cover limits.

## Global constraints

- Retain macOS 13 minimum and Swift 5.9+.
- No screen pixels, Accessibility, keyboard/clipboard access, new network functionality, telemetry or new runtime dependencies.
- Enforce the runtime capability budget above: no microphone, camera, location, personal-file/data access or other unrelated capabilities, no indirect network brokers, and session-only settings by default.
- Signed-bundle validation and the runtime startup gate must reject missing sandboxing or any entitlement beyond the exact sandbox-only allowlist. Never operate the raw unsandboxed executable as a user-facing fallback.
- Hover remains off by default; full-window coverage remains the default.
- Do not grant permissions, install, launch the UI or control the browser during implementation without the user's later authorization.
- Preserve explicit replacement, backups and staged signature validation.
- Preserve provenance honesty: no claim of reproducible builds, trusted downloaded binaries or live runtime security from static checks.
- Keep fixes on PR #1's branch; do not merge main or publish/install a release as part of these changes.

## Review focus

1. Destination appears/changes between preflight, staging and commit.
2. Parent aliases make two lexical paths refer to the same directory or route output outside the build root.
3. An impostor/invalid signer or reused PID satisfies an identity cache.
4. Source changes while a build is running.
5. Live window levels, ordering and ordinary lock behavior are mistaken for guarantees established by unit tests.
6. Direct or brokered network access, sensitive device/data access, persistence, or an unsandboxed fallback is introduced despite the app's offline-only purpose.

## Task 0: audit and enforce the offline capability boundary

**Files:** PrivacyCover.entitlements, Info.plist, Sources/HideWhatsApp/AppDelegate.swift, Settings.swift, WindowMetadata.swift, PrivacyMonitor.swift; new Sources/PrivacyCore/CapabilityPolicy.swift, SessionSettings.swift and Sources/HideWhatsApp/RuntimeConfinement.swift; scripts/verify_app.py, build_app.py; new Security/CapabilityPolicy.json and Tests/InstallerTests/test_capability_policy.py; Tests/PrivacyCoreTests/main.swift; README.md and SECURITY.md.

**Interfaces:**
- CapabilityPolicy defines schema version, exact entitlement allowlist, permitted local data flows, forbidden API/permission/handler families and allowed shipped resources. Bundle the policy as a signed local resource; never download policy updates.
- RuntimeSigningState carries own-process signature validity, signed entitlement dictionary and hardened-runtime state.
- CapabilityPolicy.validate(state: RuntimeSigningState) -> Result<Void, CapabilityViolation> is pure and independently testable.
- RuntimeConfinement validates the current running app through Security framework APIs, without spawning codesign or a shell. AppDelegate must pass this gate before starting monitoring or reading target metadata.
- WindowMetadataSource receives whether hover is enabled, so it does not read cursor/hit-test state when that capability is unnecessary.
- SessionSettings in PrivacyCore holds in-memory values initialized to the privacy defaults. The AppKit Settings adapter wraps it and emits local change notifications without UserDefaults writes.

- [ ] Produce a capability/data-flow inventory for every runtime source file and shipped helper/resource: input, purpose, retention, OS capability, and any direct or brokered egress path. Trace APIs and callers rather than relying only on text searches.
- [ ] Record the minimal budget above as a versioned local policy. Permit only the sandbox entitlement; block all unrelated permissions, usage descriptions, document/URL handlers, extensions and application-defined services.
- [ ] Write failing policy tests: a network-client/server, microphone, camera, location, file-access, automation, app-group or temporary-exception entitlement causes rejection; missing/false sandbox flag, absent hardened runtime or invalid signature also rejects startup.
- [ ] Write a startup regression proving rejected confinement prevents target-window snapshots and cover creation; no automatic permission prompt or fallback is allowed. Explicitly test an unbundled/raw executable identity.
- [ ] Write failing metadata tests proving no cursor/hit-test reads when hover is off or monitoring is disabled/suspended.
- [ ] Write a settings regression proving a new instance starts from privacy defaults and changing settings does not call a persistent-storage adapter or create app data files.
- [ ] Run new tests and observe the expected failures before implementation.
- [ ] Implement the policy, own-process startup validation, minimal metadata reads and session-only settings. Fail with a clear local error if the configured confinement is unavailable; do not request more access.
- [ ] Extend artifact verification to inspect the signed entitlement dictionary, Info.plist permissions/handlers, all bundled Mach-O executables/helpers/extensions, dynamic libraries and direct imports. Reject unapproved extra executable content. Explicitly cover network APIs, URL/web-view/broker routes, device/location APIs, user-file/import interfaces, secret access and process execution.
- [ ] Keep permitted local resource/signature operations explicit. Do not ban generic Foundation/URL/FileManager symbols indiscriminately: inspect their actual call sites and destinations so the policy remains meaningful and compatible with necessary local OS work.
- [ ] Add source-review/CI guardrails for hidden egress and capability additions, including dynamic loading, string-built endpoints and helper processes. Document that static scans are regression detectors and cannot prove the behavior of arbitrary obfuscated code.
- [ ] Add negative signed-fixture tests for unexpected capability grants/handlers and confirm that the original unmodified build still passes. Use temporary artifacts, not an installed app.
- [ ] Update packaging/snapshot inputs to include the capability policy and all runtime-confinement code, and document permitted unavoidable OS reads/writes accurately.
- [ ] Run the full suite and static signed-bundle verification, then commit this boundary before the remaining security changes.
- [ ] Keep runtime denial experiments separate from shipping code. After later launch authorization, run dedicated, reviewed fixture apps with the same restrictive entitlements to test outbound/inbound/loopback networking and personal-file denial using synthetic paths/local endpoints. Test device/location denial without granting permission or recording real sensor data.
- [ ] In that later runtime session, confirm the actual production app performs its cover job with no internet connection, no sensitive permission prompts and no app-attributed network attempts. External monitoring must distinguish this process from WhatsApp, developer tools and unrelated OS services.

This task strengthens and verifies an already narrow signed entitlement set; it is not evidence that the current app secretly uses those forbidden capabilities.

## Task 1: canonicalize paths and confine build publication (F2)

**Files:** scripts/install_bundle.py, scripts/build_app.py, Tests/InstallerTests/test_installer.py; new Tests/InstallerTests/test_build_publication.py.

**Interfaces:**
- Add canonical_install_paths(source: Path, destination: Path) -> tuple[Path, Path].
- Add build_output_destination(repo: Path) -> Path that establishes an actual managed dist directory within the canonical repository.
- install_bundle consumes the validated canonical paths and existing validator callback.

- [ ] Write failing tests: source and destination aliases are rejected; a destination through an alias physically inside the source is rejected before staging; a symlinked dist to an external fixture causes zero external mutations.
- [ ] Include positive tests for a genuinely separate install directory reached through a parent alias, so a legitimate ~/Applications alias need not be blanket-rejected.
- [ ] Run python3 -m unittest discover -s Tests/InstallerTests -v; confirm the new path regressions fail against the reviewed version.
- [ ] Resolve existing parents and source physical paths before overlap decisions; reject the destination leaf symlink; compare canonical ancestry/inode identity where necessary.
- [ ] For build output, refuse redirected dist and use a managed canonical output root. Keep staging/publication/cleanup anchored to that root, checking the directory identity at mutation boundaries rather than trusting a previously checked pathname.
- [ ] Ensure rejected path arrangements create no staging directory in the source and remove no previous app.
- [ ] Run the full suite and commit the path-boundary fix.

## Task 2: serialize publication and enforce atomic no-clobber behavior (F1)

**Files:** scripts/install_bundle.py; new scripts/atomic_publish.py; Tests/InstallerTests/test_installer.py; new Tests/InstallerTests/test_install_concurrency.py.

**Interfaces:**
- Add atomic_publish_no_replace(staged: Path, destination: Path) -> None.
- Add destination_lock(canonical_destination: Path) as a context manager for cooperating publications.
- Preserve install_bundle(source, destination, replace=False, *, validator=verify_app) -> Optional[Path].

- [ ] Add failing tests: destination created during validation stays byte-for-byte intact with replace=False; two concurrent fresh installs result in exactly one successful install and one explicit refusal.
- [ ] Add tests for failure after moving an explicitly replaced app, and a conflicting new destination during rollback. The old app must remain recoverable; rollback must not overwrite someone else's new destination.
- [ ] Run installer tests and confirm the race regression fails.
- [ ] Acquire a safe per-canonical-destination lock before replacement decisions. Do not follow a symlinked lock file.
- [ ] Use Darwin's no-replace rename primitive for publication (renamex_np/renameatx_np with RENAME_EXCL); a final exists() check plus os.replace is insufficient. The installed SDK sys/stdio.h confirms these APIs and RENAME_EXCL.
- [ ] Recheck explicit replacement permission under the lock; retain the old bundle on permitted replacement. On rollback conflict/failure, preserve and report the actual recovery path.
- [ ] Test the actual no-clobber primitive on temporary directories as well as injected I/O failures.
- [ ] Document that exception rollback is not a guarantee of a power-loss-safe two-rename transaction.
- [ ] Run the full suite and commit the transaction fix.

## Task 3: authenticate process identity and bind hover to trusted foreground PIDs (F3)

**Files:** Sources/HideWhatsApp/WindowMetadata.swift, PrivacyMonitor.swift; new Sources/HideWhatsApp/ProcessIdentity.swift; new Sources/PrivacyCore/ProcessTrust.swift; Tests/PrivacyCoreTests/main.swift; SECURITY.md.

**Interfaces:**
- ProcessIdentityFacts: pid, process-generation identity, bundle ID, code-identity validity.
- TrustedProcessPolicy.allowedPIDs(facts: [ProcessIdentityFacts]) -> Set<Int32>.
- ProcessIdentityProvider obtains running-process identity through the Security framework; WindowMetadataSource consumes the resulting trusted PID set.
- Foreground eligibility is membership of the current foreground PID in that same authenticated set, not an independent identifier-string comparison.

- [ ] Obtain and record the expected WhatsApp signing requirement from an authenticated official distribution; do not guess a Team ID or trust any signer merely because the identifier matches.
- [ ] Write failing pure tests: authentic candidate accepted; same-ID invalid/untrusted signer rejected; unrelated ID rejected; untrusted foreground PID cannot enable reveal over a trusted background window.
- [ ] Add a process-generation/PID-reuse regression and a signature-validation-error case that fails closed with an explicit unavailable/untrusted status.
- [ ] Implement the pure policy, then the OS identity adapter. Verify the running code, not only an arbitrary bundle path whose contents can differ from the process.
- [ ] Cache validation by process generation/identity and invalidate on lifecycle changes; do not perform full signature validation on every 0.1-second poll.
- [ ] Add an adapter boundary test with injected process and window providers, ensuring the actual foreground predicate uses trusted PIDs.
- [ ] Register every added CLI test in the harness and derive reported counts from the executed test collection; confirm each new regression actually runs and fails before its fix.
- [ ] Run the full suite and release/static checks; record sandbox compatibility of running-code validation as a later live acceptance prerequisite.
- [ ] Commit the identity fix.

## Task 4: compile an immutable input snapshot and strengthen artifact rejection tests (F4)

**Files:** scripts/build_app.py; new scripts/source_snapshot.py; new Tests/InstallerTests/test_build_provenance.py and test_verify_app.py; README.md; SECURITY.md.

**Interfaces:**
- prepare_source_snapshot(repo: Path, workspace: Path) -> SourceSnapshot.
- SourceSnapshot carries snapshot_root, original_revision, and a deterministic input hash manifest.
- The compiler consumes snapshot_root; the manifest is derived from exactly that snapshot. Existing installer consumes the resulting verified app.

- [ ] Add a failing pipeline test: a source changes after the compiler boundary; the final artifact must never claim the changed file was compiled when it was not.
- [ ] Add tests for stable dirty inputs, unsupported/symlinked input rejection and a source deletion during snapshot preparation.
- [ ] Build from a private fixed copy of all declared package/build inputs. Hash that copy and keep it stable through compilation/signing; never hash the unrelated live tree after compilation as compiler-input evidence.
- [ ] Record original revision separately from input hashes, and accurately label dirty snapshots. Do not silently build an unreviewed different branch.
- [ ] Do not rely solely on before/after live-tree hashes as proof: an intervening change and restoration can evade that scheme.
- [ ] Add signed-artifact negative tests for an extra network entitlement, absent hardened runtime, modified sealed resource and unexpected linked library. Synthetic tools may cover parser/error paths; also inspect real locally built artifacts without launching them.
- [ ] Include Task 0's capability policy and runtime-confinement files in the exact compiler/package snapshot; reject a build whose policy differs from the reviewed budget.
- [ ] Ensure failed snapshot/build/verification publishes nothing and preserves the previous generated artifact.
- [ ] Run the full suite, release/static checks and commit the provenance fix.

## Verification and acceptance gate

- [ ] Run ./scripts/test.sh across all new tests, with zero failures.
- [ ] Run ./build-app.sh and verify exact final signature, entitlements, imports and libraries.
- [ ] Verify the complete capability inventory, exact sandbox-only entitlement allowlist, signed local policy, startup refusal paths, absence of sensitive permission descriptions/handlers, session-only storage and hover-dependent metadata access.
- [ ] Run bash -n on shell entrypoints and git diff --check.
- [ ] Update PR #1 with the new findings, fixes, evidence and remaining limits; confirm its GitHub checks. Do not merge it automatically.
- [ ] Ask the user to review the concrete amended PR before any app installation/launch.
- [ ] Only in a later authorized runtime session: use non-sensitive fixtures/chats to test sandbox metadata and code-identity access; multiple genuine windows, pop-outs/calls and levels; overlap/ordering; Spaces/fullscreen; display changes; sleep/wake/session switching and ordinary screen lock; login status; and external runtime network observation.
- [ ] In that session, demonstrate normal operation offline; use reviewed isolated fixtures to verify denied networking and personal-file access, and verify no microphone/camera/location access or permission grants. Record actual OS-enforced results rather than treating absent symbols or entitlement flags as complete runtime proof.
- [ ] If a promised surface is unsupported, either implement a verified approach that preserves the permission boundary or explicitly narrow the supported behavior. Do not compensate by granting broad permissions automatically.
- [ ] Keep screen-share redaction and crash fail-closed secrecy outside the guarantee unless the architecture is changed and independently validated.

## Suggested order and stop condition

Start with Task 0 to define and enforce the user-mandated offline capability boundary. Then implement Tasks 1–2 for reproduced local write/replacement effects, Task 3 for process trust and Task 4 for source-to-artifact evidence. All later work must preserve Task 0's policy. Leave runtime acceptance until after review and explicit authorization.

Source implementation and offline/static verification are recorded in docs/security-execution.md. Live UI/network/device-denial acceptance remains deferred until after PR review and later authorization, as required by the plan.

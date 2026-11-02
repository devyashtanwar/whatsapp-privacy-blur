# WhatsApp distribution identity compatibility implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Authenticate supported App Store and Developer ID WhatsApp processes offline, retain rejection of impostors, and explain authentication failures accurately.

**Architecture:** Replace the universal certificate-OU requirement with explicit distribution branches. Keep Apple-anchored validation of the running process and PID/launch-generation binding. Carry typed, in-memory validation failures through to the menu, rather than collapsing every error into a publisher accusation.

**Tech Stack:** Swift/AppKit/Security, existing framework-free core tests and Python artifact checks.

**Spec:** User request and investigation evidence below; source/security requirements in SECURITY.md remain applicable.

## Evidence and diagnosis

- Screenshot: Enabled and full-window cover checked; menu reports publisher authentication failure; no cover visible.
- ProcessIdentity.swift requires certificate leaf subject OU 57T9237FN3 for every distribution. WindowMetadata.swift returns an empty environment when no process passes.
- Read-only codesign verification outside the agent restriction confirms the installed WhatsApp bundle and running process are valid under their designated requirement. Existing custom requirement fails both.
- Installed signing chain: Apple Mac OS Application Signing -> Apple Worldwide Developer Relations Certification Authority -> Apple Root CA. App Store signing branch OID 1.2.840.113635.100.6.1.9 passes.
- Signed entitlements: com.apple.developer.team-identifier = 57T9237FN3; both application-identifier and com.apple.application-identifier = UKFA9XBX6K.net.whatsapp.WhatsApp. Application identifier prefix differs from team ID; do not derive one from the other.
- Narrow proposed App Store requirement with Apple anchor, signing identifier, App Store certificate OID, signed team identifier and signed com.apple.application-identifier passes both bundle and running process checks.
- Default agent-restricted codesign reported CSSMERR_TP_NOT_TRUSTED/authority unavailable; read-only verification outside that restriction succeeds for the proper requirement. Therefore previous agent-environment failures alone were not evidence that WhatsApp is invalid.
- These CLI checks do not establish compatibility inside the utility's sandbox or prove offline operation of the app adapter. Existing adapter still needs live acceptance with explicit noNetworkAccess flags.

## Global constraints

- Only com.apple.security.app-sandbox entitlement; no extra permissions, network, helper service, shell execution or sensitive-data access in the utility.
- Every dynamic/static code-validity call retains strict validation and SecCSFlags.noNetworkAccess.rawValue.
- Never accept bundle ID, path, unverified TeamIdentifier string, or ad-hoc signature alone. Never copy the target's own designated requirement as the trust policy.
- No changes to system trust, Gatekeeper, quarantine, WhatsApp, or certificate settings. No persistent diagnostics or user-content collection.
- Scope is identity compatibility and diagnostics; unrelated overlay behavior remains subject to acceptance testing.

## Review focus

- App Store certificate OU and publisher Team ID differ: supported store fixture must pass.
- Developer ID signed code must remain constrained to the WhatsApp publisher and correct distribution certificate types.
- Correct bundle ID with wrong publisher, unsigned/ad-hoc code, changed code, missing/wrong signed app ID and developer certificate must fail.
- PID reuse, process termination/relaunch, missing generation, and cached errors must never confer stale trust.
- In-sandbox guest lookup/validation denial must be distinguishable from a publisher mismatch and must not enable monitoring.

## Task 1: Distribution-aware running-code requirements

**Files:** Sources/HideWhatsApp/ProcessIdentity.swift; new Sources/PrivacyCore/TargetIdentityPolicy.swift; Tests/PrivacyCoreTests/ProcessTrustTests.swift; existing test harness registration as needed.

**Interface:** TargetIdentityPolicy exposes fixed Developer ID and App Store requirement strings; ProcessIdentityProvider applies their explicitly grouped union to the running SecCode. Keep registry generation binding.

- [ ] Add regressions for exact fixed identity constants and requirement generation, including the different App ID prefix. Use the Security adapter fixture to reproduce current store rejection before changing the policy; pure string tests alone are insufficient proof of acceptance.
- [ ] App Store branch: Apple generic anchor, signing identifier net.whatsapp.WhatsApp, leaf OID 1.2.840.113635.100.6.1.9, signed entitlement com.apple.developer.team-identifier 57T9237FN3, signed entitlement com.apple.application-identifier UKFA9XBX6K.net.whatsapp.WhatsApp.
- [ ] Developer ID branch: Apple generic anchor, signing identifier net.whatsapp.WhatsApp, intermediate OID 1.2.840.113635.100.6.2.6, leaf OID 1.2.840.113635.100.6.1.13, certificate leaf OU 57T9237FN3. Confirm against an authenticated Developer ID distribution before claiming that channel verified; do not loosen based on absent fixture.
- [ ] Keep strict/offline flags and process-generation recheck. Reject nil requirement, failed validation and any unsupported identity.
- [ ] Verify actual Security API requirement compilation, positive store fixture and negative unsigned/ad-hoc impostor fixtures in a separate developer test harness, never bundled into the utility. Tests lacking an authentic distribution fixture must report it explicitly, not count skipped checks as verified.
- [ ] Run core/source-policy tests and commit only after reviewing source-policy compatibility.

## Task 2: Accurate local failure reasons

**Files:** Sources/PrivacyCore/ProcessTrust.swift; Sources/HideWhatsApp/ProcessIdentity.swift; Sources/HideWhatsApp/WindowMetadata.swift; Sources/HideWhatsApp/PrivacyMonitor.swift; Sources/HideWhatsApp/StatusBar.swift; Tests/PrivacyCoreTests/ProcessTrustTests.swift.

**Interface:** Typed validation outcome with success or stage (requirement creation, guest lookup, validity check, generation changed) plus optional OSStatus. Registry preserves typed outcomes per candidate; allowed PID set derives only from success. Window source exposes current failure state for status rendering.

- [ ] Add failing tests for distinct access/trust/identity failures, stale cached outcomes after invalidation and PID reuse, and no metadata snapshot when unauthenticated.
- [ ] Return Security API stage/error codes instead of a bare Bool. Use SecCopyErrorMessageString for optional local error detail; collect no chat/window title/file history, and write no logs.
- [ ] Show that protection is inactive when authentication fails. Distinguish process access failure from requirement rejection; do not label a genuine signature mismatch as a confirmed malicious app.
- [ ] Add an explicit menu retry that invalidates cached identity results and synchronizes; test it cannot mark a failed candidate trusted. Preserve lifecycle cache invalidation.
- [ ] Run affected tests and commit.

## Task 3: Signed sandbox acceptance and documentation

**Files:** README.md; SECURITY.md; docs/runtime-capability-audit.md; docs/security-execution.md; relevant regression tests.

- [ ] Build the exact snapshot and run PRIVACY_VERIFIED_APP="$PWD/dist/WhatsApp Privacy Cover.app" ./scripts/test.sh, including all four real signed-artifact tests. Verify sole sandbox entitlement and offline validation guardrails remain unchanged.
- [ ] Update the earlier failed-sample note: explain the demonstrated App Store policy mismatch and distinguish agent-environment trust errors from utility results. Document distribution-specific trust and remaining Developer ID fixture limitation.
- [ ] Publish a reviewable fix PR with exact tests/evidence and any unverified distribution explicitly identified.
- [ ] User acceptance: quit previous cover utility, replace with verified new bundle, launch with harmless chats; confirm no sensitive permission prompts, trusted target status and actual full-window cover.
- [ ] If sandbox guest lookup/validation still fails, use new stage/error diagnostic to investigate; do not add broad file access, relax sandbox, use a helper, enable network, or replace live process validation with an unbound on-disk check.
- [ ] Verify foreground/background, resizing, minimize/restore, Spaces and relaunch/PID generation behavior; check network silence separately if required. No personal-use readiness claim until live acceptance passes.

Reference: Apple's TN3127 Inside Code Signing: Requirements documents distinct Mac App Store and Developer ID certificate constraints: https://developer.apple.com/documentation/technotes/tn3127-inside-code-signing-requirements

Status: Plan only. No production implementation, app launch, desktop control, installation or permission changes performed for this investigation.

Execution status: implementation and local tests complete for Tasks 1–2. Task 3 local release verification and independent review passed; publication pending. Developer ID positive fixture and full GUI acceptance remain explicitly pending; see docs/whatsapp-identity-execution.md for evidence and rulings.

# WhatsApp Privacy Cover

A local macOS menu bar utility that places opaque covers over WhatsApp Desktop windows. This privacy-focused fork replaces the upstream screenshot blur with solid covers.

**No screenshots. No Accessibility permission. No Screen Recording permission. No analytics, network functionality, or third-party packages.**

This is visual concealment for nearby observers. It is not an app lock, encryption, malware protection, or dependable screen-sharing redaction. Read [SECURITY.md](SECURITY.md) before use.

## Defaults and controls

- Entire WhatsApp window covered by default, including chat bodies.
- Hover reveal disabled by default. Enable **Hover to reveal window** only if you accept that moving the pointer over a cover reveals that window.
- Disable **Cover entire window** for sidebar + header coverage. This exposes chat bodies. Sidebar width is manual (200–500 points) and needs checking against your layout.
- Disable **Enabled** to remove covers and stop window monitoring. Re-enabling recomputes visible windows immediately.
- Background-visible WhatsApp windows remain tracked; revealing stops when another app becomes foreground.
- Multiple visible regular WhatsApp windows are tracked individually.
- Covers block clicks while opaque. When revealed, clicks pass through to WhatsApp.
- Settings are session-only and reset to privacy defaults each launch; no preference/history files are deliberately written.
- Launch at Login is opt-in and uses macOS's login-item service. Registration failures are shown.

## Requirements

macOS 13 or newer, Apple's Swift 5.9+ command-line tools, Python 3, and WhatsApp Desktop (bundle ID `net.whatsapp.WhatsApp`). No Apple developer account is needed for a local ad-hoc signed build.

No sensitive-data permission is required by this version. Do not grant Accessibility, Screen Recording, Input Monitoring, Full Disk Access, camera or microphone access to make it work.

## Review and test before installation

```bash
./scripts/test.sh
./build-app.sh
```

The tests exercise synthetic geometry/lifecycle inputs and temporary installer fixtures. They do not open WhatsApp, place windows on your desktop, or grant permissions.

The core tests use a small command-line assertion harness so they run with Command Line Tools without XCTest, compiler macro plugins, or a full Xcode setup. The suite exits nonzero on failure. After a build, run `PRIVACY_VERIFIED_APP="$PWD/dist/WhatsApp Privacy Cover.app" ./scripts/test.sh` to include real signed-artifact rejection tests; they inspect temporary copies without executing the app. `scripts/test.sh` is the complete project test command.

The build command produces `dist/WhatsApp Privacy Cover.app`, signs it locally with App Sandbox and hardened runtime, then verifies its signature, entitlement allowlist, sensitive API imports and dynamic-library dependencies. It **does not install or launch the app**. Build intermediates and caches stay under `.build/`.

The startup gate also validates its own signature, runtime hardening and signed local capability policy before any target monitoring. Unsandboxed/raw executables are refused, with no permission-granting fallback.

The final app's only explicit entitlement is `com.apple.security.app-sandbox`. No network-client/server, broad filesystem, automation or device entitlements are included. Running the raw Swift package executable bypasses this bundle signing configuration; use the verified app bundle for later runtime evaluation.

`Contents/Resources/source-manifest.json` records the base Git revision and exact private-snapshot input hashes, including dirty source inputs. Compilation uses that fixed snapshot; later edits to the live checkout do not change its manifest. `dist/HideWhatsApp.sha256` records the signed executable hash. These are provenance aids, not independently authenticated/reproducible-build proofs.

Optional Developer ID signing:

```bash
SIGNING_IDENTITY="Developer ID Application: Your Name (TEAMID)" ./build-app.sh
```

Developer ID signing alone does not notarize the app. Do not disable Gatekeeper or remove quarantine attributes; investigate any OS refusal.

## Install only after review

```bash
./install.sh
```

Installs the verified local build to `~/Applications/WhatsApp Privacy Cover.app` without launching it. An existing destination is refused. Quit the old app before explicitly replacing it:

```bash
./install.sh --replace
```

Replacement stages the new app first and retains the old bundle at an adjacent `.backup-…` path. If the final rename fails, the old app is restored. The installer never requests root or modifies OS security settings.

The fork uses `devyashtanwar.whatsapp-privacy-cover` as its bundle identifier so it does not reuse upstream preference/permission identity. If the upstream version was installed previously, quit it, disable its login item and revoke its Accessibility/Screen Recording permissions separately.

## Manual acceptance before trusting concealment

After source/PR review, test with non-sensitive chats:

1. Check the signed app starts without privacy permission prompts and covers every intended window.
2. Verify window ordering with another app in front, multiple WhatsApp windows, minimizing/hiding, moving/resizing, Spaces and full screen.
3. Check multiple displays, including displays left of/above the primary display and changes to the primary display.
4. Toggle Enabled; monitoring must stop and resume correctly. Test sleep/wake and switching user sessions. Separately check ordinary screen locking: there is no dedicated lock handler and the relevant OS notification delivery is not yet verified.
5. Check hover opt-in, focus loss, and that a window behind another window cannot be revealed by hovering the overlapping area.
6. Confirm sidebar/header-only coverage fits your WhatsApp version if you choose that less-complete mode.
7. Test login registration/unregistration and verify actual OS status.
8. Use external network/process monitoring if runtime network verification is required.

A passing source/test/build review does not certify these live OS interactions. No runtime app acceptance has been performed as part of the source changes. Target publisher checks require Apple-anchored code for net.whatsapp.WhatsApp / Team 57T9237FN3, cached by PID plus launch generation. The installed sample did not pass strict Apple-anchor verification in this execution environment; an authenticated official distribution and live sandbox compatibility must be validated before use. There is no same-ID or unsigned fallback. See [capability audit](docs/runtime-capability-audit.md).

## Architecture

- `Sources/PrivacyCore`: validated window metadata, coverage geometry and lifecycle policy.
- `Sources/HideWhatsApp`: metadata-only OS adapter, opaque AppKit windows, one monitoring timer, settings/menu and opt-in login service.
- `Tests/PrivacyCoreTests`: synthetic executable tests.
- `Tests/InstallerTests`: filesystem installation/rollback tests.
- `scripts`: local build, signing, verification and staging.
- `.github/workflows/verify.yml`: macOS tests/build verification; no release publishing.

Derived from [realhasanshoaib/whatsapp-privacy-blur](https://github.com/realhasanshoaib/whatsapp-privacy-blur), upstream base `da50ac5d4817d6098d984f9312e73b1f6c38ca05`. MIT license; see [LICENSE](LICENSE).

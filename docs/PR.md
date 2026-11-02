# Replace screenshot blur with a permission-free privacy cover

The upstream app captured screen regions beyond WhatsApp, continued capture after disabling, and required broad Accessibility trust. This change removes the sensitive-data path: opaque windows use only window geometry, with no screenshots or Accessibility API.

- Full-window coverage and no hover reveal by default; opt-in partial coverage/hover.
- One guarded monitoring timer; disabling/session suspension stops reads and clears covers. Background-visible and multiple windows are tracked.
- Validated geometry and metadata; primary-display coordinate conversion; hover gated by the actual window under the cursor.
- New bundle identity; sandbox-only entitlement and hardened-runtime signing; no network entitlements/dependencies.
- Build-only artifact command with signature/entitlement/import/library verification.
- Staged non-root installer; replacement opt-in, previous bundle retained, rollback on rename failure.
- Synthetic policy/geometry tests, installer fault tests, macOS CI and explicit privacy limits.

## Validation
Local synthetic core and installer tests pass. Release build and static signed-bundle verification pass. Exact final counts and review findings are recorded in docs/implementation-progress.md.
The local Command Line Tools linker reports missing optional developer search-path warnings; builds still complete. Full Xcode is not used because its license has not been accepted on this machine. No license or system developer setting was changed.

## Required acceptance before installation/personal use
The app was not launched or installed and no permission was granted. Live sandbox metadata access, cross-app window ordering, Spaces/fullscreen/multi-display behavior, hover interaction, login service, and runtime network silence still require the README acceptance checks. This is visual concealment, not guaranteed screen-sharing redaction or an app lock.

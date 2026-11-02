# Privacy hardening implementation plan
> Execute inline, with test-first policy/geometry changes and an independent final review.
Goal: remove screenshot and Accessibility access, repair lifecycle controls, and provide a reviewable build.
Architecture: pure PrivacyCore computes cover plans; AppKit adapters supply metadata and render opaque covers. A single coordinator reconciles state.
Tech stack: Swift 5.9+, AppKit/CoreGraphics, framework-free CLI core tests, shell/Python standard library only.
Spec: ../specs/2026-11-02-privacy-hardening-design.md

## Global constraints
macOS 13+; no external dependencies; no network or sensitive-data permissions; no application launch/install before user review.

## Review focus
Disabled/suspended state must cause no metadata reads or visible covers.
Foreground change must reset revealed covers.
Geometry must handle negative screen origins and narrow windows.
Multiple windows and malformed metadata must not cause unsafe frames.
Installer failures must preserve existing installations.

## Tasks
1. Write failing synthetic state/geometry tests (disabled, enable, suspend, focus, all windows, small/invalid geometry); extract PrivacyCore and implement them to green.
2. Replace capture/AX adapters with metadata-only provider and opaque windows; wire one lifecycle coordinator and simplified settings/menu. Build and test.
3. Add staged build/sign/verify + non-destructive installer with behavior tests; add macOS CI and exact privacy/limitation docs.
4. Run full tests, release build, signature/entitlement/static checks; independently review branch, fix defects with regressions, commit.
5. Create fork/branch/PR through authorized non-UI tools if capability exists; otherwise preserve a ready branch and report the exact remote blocker.

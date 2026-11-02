# Privacy hardening progress
Upstream base: da50ac5d4817d6098d984f9312e73b1f6c38ca05.
Workspace: dedicated fresh clone; branch codex/privacy-hardening. No synced project reference files modified.
Design choice: user selected solid cover and explicitly requested implementation. No browser/computer-control use after the user's restriction.

## Work completed so far
- Core lifecycle/geometry: initial CLI run 9 tests, 27 assertions, 16 failures against API scaffolding; after implementation 0 failures.
- Hover occlusion and metadata filtering: 11 tests, 30 assertions; additions failed in 3 assertions before implementation, then passed.
- Installer: 8 behavior/fault tests failed against scaffolding, then all passed.
- App adapters replaced screenshot/AX code; debug and release builds succeed.
- Signed artifact verified: valid signature, hardened-runtime bit, exact sandbox-only entitlements, no forbidden direct imports, system-only linked libraries.
- No app installation, launch, UI interaction, permission grant or WhatsApp content access.

## Decisions made
- Use a tiny framework-free command-line core test harness. The selected Command Line Tools lack XCTest; their default build engine's Testing macros also fail to resolve. Full Xcode refuses use until its license is accepted. No license was accepted or global toolchain changed.
- Opaque covers and manual geometry eliminate Accessibility and Screen Recording rather than narrowing those permissions.
- Full-window mask and hover off are privacy defaults; reduced concealment remains explicit opt-in.
- Source manifest hashes dirty inputs, so provenance is recorded without claiming reproducible builds.
- A local signing-verifier regex incorrectly rejected a valid runtime flag; changed to testing codesign's numeric runtime bit, then signed-bundle verification passed.
- Runtime concealment, sandbox metadata compatibility and network tracing remain acceptance work after PR review; they cannot be established without launching the app.

## Environment warnings and publication
The local Command Line Tools linker warns about absent optional developer library/framework search paths; successful binaries link only system libraries.
The user created devyashtanwar/whatsapp-privacy-blur after the connector's missing fork operation initially blocked publication. Connected GitHub access now confirms write permission and the expected upstream base on main. Publication uses the connector only; no browser/computer-control use.

## Independent review and fix
Reviewer examined the committed branch in a separate read-only context and independently reran the original eight installer tests.
One P2: the staged bundle itself must be verified before replacing the destination.
Fixed with a default signed-bundle validator invoked after staging and before destination renames. New validation-failure test failed first, then passed; all nine installer tests pass.
No other concrete source-level defects were reported. Dedicated lock handling was considered but remains an explicit acceptance limitation; ordinary lock behavior is not claimed.
No deferred code-review minors. Formatting warnings were cleaned up.

## Remaining
Local implementation and independent review fix are complete. Publish the verified source tree to the user's fork and open a review PR; live runtime acceptance remains after review.

## Final verification
- ./scripts/test.sh: 11 core tests / 30 assertions / 0 failures; 9 installer tests / 0 failures.
- ./build-app.sh: release build successful; signature, hardened-runtime bit, sandbox-only entitlement, forbidden-import checks, and system-library checks pass on both built and staged bundles.
- bash -n build-app.sh install.sh scripts/swift.sh scripts/test.sh: pass.
- git diff --check against upstream base: pass.
- Verified executable SHA-256: ef2194494a6f7d62223bd9a652a0dce21a73ca94947249e8345119a22805c742.
- No runtime acceptance, installation, permission changes or app launch performed.
- The user supplied the fork URL; code and PR description are ready for publication.

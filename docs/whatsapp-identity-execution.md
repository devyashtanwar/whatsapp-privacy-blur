# WhatsApp identity compatibility execution record

Plan: docs/superpowers/plans/2026-11-02-whatsapp-distribution-identity.md.
Base: merged main 17d5735. Source changes and PR publication authorized; do not install or launch the GUI utility or change permissions.

Task 1: Real strict/offline Security API App Store fixture initially rejected with -67050 using the original certificate-OU assumption (RED). Distribution-aware policy accepted it (GREEN). Fixed Apple-anchor and certificate OID requirements plus exact signed team/application identity are preserved; no same-ID or unsigned fallback.

Task 2: Added typed validation/cache tests before replacing Bool results (RED interface mismatch). Core suite passes with 77 assertions, including typed failures, invalid candidates, PID reuse, cache invalidation/retry and stale failure clearing. Menu presents inactive status, local stage/OSStatus detail and an explicit retry. No diagnostics persisted.

Task 3: Release snapshot build, signature/capability/layout/API/library verification passed. Full tests: 14 core checks / 77 assertions / 0 failures; 52 Python tests / 0 failures / one explicit Developer ID fixture skip. The real App Store fixture, sandbox-only running-process check and four real signed-artifact tests ran. Final binary SHA-256: 72783450b3cf25029a92ed829848604216d1703f288791c8fa8a579a544078e3. PR publication pending.

Ruling: The official Developer ID distribution fixture is unavailable here. Keep the documented Apple Developer ID certificate constraints and fixed publisher, report its positive fixture test skipped, and do not claim that distribution verified. Cost: users of that channel still need authenticated-fixture/live acceptance.

Ruling: Read-only tests of already-running WhatsApp are permitted, but GUI acceptance remains for the user. A temporary command-line-only harness signed with exactly App Sandbox + hardened runtime successfully authenticated the existing running WhatsApp using strict no-network validation. It installs nothing, displays no windows, and reads no chats. Cost: this establishes validator compatibility, not live overlay coverage or network silence for the full GUI app.

Fixture setup initially tried shutil.copy2('/bin/echo'), which attempted to copy protected system-file flags and failed. Changed the temporary fixture to copyfile + executable mode; no production code was changed to work around that test setup problem.

Final review: One independent read-only reviewer found no critical or important issues. No minor fixes were deferred.

Final: Ruling: Developer ID positive compatibility remains uncertified without its fixture; preserve that explicit skip and limitation. Cost: that distribution still needs acceptance.
Final: Ruling: GUI cover/menu interaction and full-app runtime network silence remain uncertified; the user retains live acceptance after PR review. Cost: validator success alone cannot establish visual coverage or complete runtime behavior.
Final: Ruling: The tampered code fixture is ad-hoc and already fails the anchor. It proves rejection of that impostor, not isolated tamper detection on a trusted WhatsApp signature. Existing signed-artifact tests independently verify tamper rejection of the utility bundle. No claim of trusted-target tamper-fixture coverage is made. Cost: that specific trusted-target mutation case is not exercised.

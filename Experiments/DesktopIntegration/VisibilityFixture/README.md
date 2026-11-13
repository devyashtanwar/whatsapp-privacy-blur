# User-operated public window-ordering fixture

This separate test uses invented pixels only. It does not capture WhatsApp or other apps, read their content, request Screen Recording, or bypass the beta's publisher validation. Its owner and observer are separate processes. Neither fixture module nor its fixture-only bundle check enters the beta package graph.

Build only:

```
python3 scripts/build-visibility-fixture.py
```

The agent must not launch these apps. The user can open `dist/Visibility Fixture Owner.app`, note the window number shown in its invented image, then open `dist/Visibility Fixture Observer.app` and enter that number. Attach. The observer draws its own generated blurred copy using the production TargetPresentation implementation.

Check that the synthetic preview is blurred while its name, instructions and other UI remain clear. Place observer settings or another app over half the fixture: exposed synthetic content must retain blur and the overlay must never paint above the covering app. Activate other apps, drag the fixture and overlapping windows, and check transparent overlays. Quit using each app's menu/Command-Q. No real-chat screenshots are required.

Report whether ordering is confirmed and whether blur remains correctly layered. “Unconfirmed” means this public ordering path has not passed its gate; it is not evidence of private-data protection. This fixture does not certify OCR, real capture, Spaces, full screen, input alignment or performance. No production rollout before real acceptance.

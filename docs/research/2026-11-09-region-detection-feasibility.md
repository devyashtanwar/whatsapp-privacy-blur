# Native region detection investigation — 2026-11-09

Status: historical investigation record, not a production blur implementation. Runtime OCR was subsequently explicitly authorized for the separate test candidate; see [2026-11-12 candidate record](2026-11-12-native-test-candidate.md). Statements about isolation below describe the earlier checkpoint, not the current candidate.
Base: 2c146135245641d4e0ff371efa6d522fd8942e2f.

The user reported selecting WhatsApp in the access preview and requested proceeding to production-app testing without another separate access test. Treat that as authorization to continue implementation and as a reported picker interaction, not proof of the exact final frame-validation status. Runtime selection/authentication checks remain mandatory; no repeated manual selection report is requested here.

## Concrete experiment

Added a separate GeometryAnalysis target and GeometryTests command to the integration package. It is not a dependency of DesktopBlurPreview: no geometry/OCR code is connected to a captured private frame or added to the existing production executable.

The helper uses Apple's VNDetectTextRectanglesRequest and returns bounded pixel rectangles only. It does not request recognized strings. The test renders an invented name, sidebar preview, conversation message and an image-only message card into an in-memory NSImage. No visible window, screen capture, WhatsApp inspection, personal file, screenshot export or private text was used.

The empty scaffold failed three detection assertions. Apple's implementation detected three text rectangles and passed four probe assertions. An intermediate fixture incorrectly assumed logical points equalled backing pixels on a Retina display; its coordinate expectations were corrected using the generated image's actual pixel dimensions. The detector's coordinate contract remains image pixels.

## Finding and limits

The text-only candidate supplies positions without message/name/avatar roles and does not cover the image-only message card. Its output alone is not a valid provider for the requested independently selectable categories or media protection. Do not turn these rectangles into a protected status or ship fixed row/pane guesses as if region discovery were solved.

This rejects a text-rectangle-only provider. It does not prove that every structural image-analysis approach is impossible, or that OCR alone would solve message detection. Bubble/media segmentation, clipping/scroll correspondence, UI-anchor detection and supported-layout evidence still need implementation and validation. Task 3/Gate B is not complete.

## Processing decision and authorized investigation

The original approved design excluded OCR. The user subsequently answered “Allow on-device OCR investigation” to the explicit question about selected-window UI anchors, transient strings, no logging/storage/network and no broader OS permission. This supersedes the investigation-only OCR restriction; it does not certify a message detector or authorize Accessibility, broad capture, storage or model downloads.

Implemented a separate UIAnchorRecognition research helper using Apple's VNRecognizeTextRequest on generated content only. Its result contains whitelisted enum categories and pixel bounds, never recognized strings. Matching labels are constrained to candidate UI zones. Eight geometry/anchor assertions pass: three generated text rectangles, three expected UI anchors and rejection of a matching word inside the message body. The empty anchor scaffold failed four assertions; an initial implementation's Swift multi-pattern where condition failed two isolation tests and was corrected with explicit position guards. Those are substantive checks, not native WhatsApp evidence.

These are candidate label matches, not structural proof: a personal name can equal a UI label, OCR can miss text, and image-only messages still require their own geometry. Neither this helper nor the generic text detector is linked into the capture executable. The source auditor allows recognition only in the exact investigation file, rejects OCR elsewhere and rejects importing the research module from runtime code. All unrelated API prohibitions remain in effect.

Added source-audit regressions rejecting the legacy VNRecognizeTextRequest and newer RecognizeTextRequest before the user authorized the narrow investigation exception: two negative cases failed before the audit check was added. These are static regression guards, not a malware detector.

## References

- Apple text-region detection: https://developer.apple.com/documentation/vision/vndetecttextrectanglesrequest
- Apple text observation geometry: https://developer.apple.com/documentation/vision/vntextobservation
- Apple recognized text request, invoked only on generated fixtures: https://developer.apple.com/documentation/vision/vnrecognizetextrequest
- Installed SDK VNObservation.h also confirms that VNTextObservation adds character boxes, not application-specific roles.


## Independent production contract work

Alongside the authorized OCR investigation, added FrameBinding/RegionSnapshot/RegionValidator contracts and regression cases for all 16 category combinations, process/window/session/frame identity, image size/scale/window-position mismatches, freshness budgets, duplicate/invalid masks, control overlap and covering an identity category that the user left disabled. The pass-through scaffold failed 39 of the initial249 integration assertions. Text-only and synthetic-fixture evidence are explicitly rejected as live-layout proof.

These contracts do not implement a layout provider, prove semantic coverage or reject a global reordered stream independently. A future coordinator must supply the latest trusted capture binding; the provider must establish complete category geometry. No source of current WhatsApp message regions is implemented, and no new protection status is enabled by this work. Freshness is a required caller-supplied positive finite budget; no live performance/privacy budget has been certified by synthetic tests.


## Native fixture still required before a supported-layout claim

The existing native reference shows an archived list with no opened conversation. The active-message examples in the conversation are Web extensions, not the native application's message view. Neither a picker selection report nor generated AppKit views validates real native message/media bounds. To develop and validate a native layout provider without inspecting the user's desktop, request a native WhatsApp screenshot with harmless self/test-chat content, sensitive sidebar details redacted, and the WhatsApp version. Do not add that image or recognized strings to the public repository. This is an evidence gap, not a request for another access test or a claim that local OCR alone solves production integration.


## Review and verification

Independent review found an Important dependency-audit gap: a valid concatenated Swift dependency expression or source remapping bypassed the bracket-only parser. Two negative cases failed against the parser. The fix pins the exact reviewed manifest, binds that pin in sealed provenance and rejects Vision linkage in the capture executable. It does not purport to resist an attacker who rewrites the builder and pins together.

The report's obsolete “not invoked” / “decision pending” wording was corrected after authorization and actual generated-fixture OCR runs; this is a processing-accounting correction. Deferred test limitation: the synthetic OCR fixture checks candidate counts rather than exact composer bounds, and media noncoverage is a measured observation rather than a regression assertion. Neither is evidence of native geometry coverage. Existing deferred build limitation: changing checkout revisions while copying inputs can mislabel baseRevision; file hashes still bind the actual copied bytes.


Verification: 251 integration core assertions, 10 ScreenCaptureKit configuration assertions and 8 generated-image geometry/anchor assertions pass. The full repository suite passes 79 Python tests with three explicit authentic-fixture/live-process skips. The separately signed capture-only preview builds/verifies and does not link Vision. An additional re-signed binary fixture with a Vision load command was accepted when the binary guard was temporarily removed (one RED failure), then rejected after restoring it; the complete suite passed. No fixture executable or GUI was launched. These results do not complete Task 3/Gate B or produce a native message-blur release.

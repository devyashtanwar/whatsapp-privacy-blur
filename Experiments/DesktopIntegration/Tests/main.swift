import Foundation
import IntegrationCore
import CoreGraphics
var failures = 0
var count = 0
func check(_ value: @autoclosure () -> Bool, _ message: String) {
    count += 1
    if !value() { failures += 1; print("FAIL: \(message)") }
}
for bits in 0..<16 {
    let s = BlurSettings(sidebarPreviews: bits & 1 != 0, conversationMessages: bits & 2 != 0,
                         names: bits & 4 != 0, avatars: bits & 8 != 0, sidebarHover: true, conversationHover: true)
    check(s.needsCapture == (bits != 0), "all-disabled alone stops capture, combination \(bits)")
    check(s.isEnabled(.sidebarPreview) == (bits & 1 != 0), "sidebar independent \(bits)")
    check(s.isEnabled(.conversationMessage) == (bits & 2 != 0), "conversation independent \(bits)")
    check(s.isEnabled(.contactName) == (bits & 4 != 0), "name independent \(bits)")
    check(s.isEnabled(.avatar) == (bits & 8 != 0), "avatar independent \(bits)")
    check(s.permitsHover(.sidebarPreview) == (bits & 1 != 0), "sidebar hover requires enabled category \(bits)")
    check(s.permitsHover(.conversationMessage) == (bits & 2 != 0), "conversation hover requires enabled category \(bits)")
    check(!s.permitsHover(.contactName) && !s.permitsHover(.avatar), "message hover never reveals identity \(bits)")
}
let defaults = BlurSettings()
check(defaults.needsCapture && !defaults.names && !defaults.avatars, "default categories")
check(!defaults.permitsHover(.sidebarPreview) && !defaults.permitsHover(.conversationMessage), "hover off by default")
for (input, expected) in [(-1.0, 0.4), (0.4, 0.4), (0.65, 0.65), (0.9, 0.9), (2.0, 0.9), (.infinity, 0.65), (.nan, 0.65)] {
    check(BlurSettings(tint: input).tint == expected, "normalize tint \(input)")
}
var edited = BlurSettings(); edited.tint = .nan
check(edited.tint == 0.65, "editing tint also validates")
// These tests catch auto-capture, cross-session callbacks and accepting untrusted/wrong-scope input.
let selected = SelectionDescriptor(windowID: 42, pid: 123, generation: 10, bundleIdentifier: "net.whatsapp.WhatsApp", singleWindow: true, trusted: true)
func ready() -> (CaptureSession, UInt64) {
    let session = CaptureSession()
    let token = session.request(settings: BlurSettings(), now: 100) ?? 0
    _ = session.accept(selected, token: token, now: 100)
    return (session, token)
}
let idle = CaptureSession()
check(!idle.wantsFrames && idle.target == nil, "launch never captures")
check(idle.request(settings: BlurSettings(sidebarPreviews: false, conversationMessages: false), now: 1) == nil, "all disabled cannot select")
for mutate in 0..<6 {
    var wrong = selected
    switch mutate {
    case 0: wrong.singleWindow = false
    case 1: wrong.trusted = false
    case 2: wrong.bundleIdentifier = "com.example.spoof"
    case 3: wrong.windowID = 0
    case 4: wrong.pid = -1
    default: wrong.generation = .nan
    }
    let c = CaptureSession(); let t = c.request(settings: BlurSettings(), now: 100) ?? 0
    check(!c.accept(wrong, token: t, now: 100) && !c.wantsFrames && c.target == nil, "reject invalid selection \(mutate)")
}
let (live, token) = ready()
check(live.wantsFrames && live.target?.windowID == 42 && live.state == .awaitingFrames, "trusted picker selection alone allows awaiting one test frame")
live.stop()
check(!live.wantsFrames && live.target == nil, "stop clears target")
check(!live.accept(selected, token: token, now: 101), "late selection after stop cannot restart")
check(!live.consumeFrame(token: token, capturedAt: 100, now: 101, width: 100, height: 100, targetStillTrusted: true), "late frame after stop rejected")
for invalid in 0..<7 {
    let (c, t) = ready()
    let ok = c.consumeFrame(token: invalid == 0 ? t + 1 : t,
                           capturedAt: invalid == 1 ? 90 : (invalid == 2 ? 102 : 100),
                           now: 100.1, width: invalid == 3 ? 0 : (invalid == 4 ? 20000 : 100),
                           height: invalid == 5 ? -1 : 100, targetStillTrusted: invalid != 6)
    check(!ok, "reject wrong-session/stale/future/invalid-sized/untrusted frame \(invalid)")
    if invalid != 0 { check(!c.wantsFrames && c.target == nil, "invalid current frame stops capture \(invalid)") }
}
let (once, t) = ready()
check(once.consumeFrame(token: t, capturedAt: 100, now: 100.1, width: 100, height: 100, targetStillTrusted: true), "valid current frame accepted once")
check(!once.wantsFrames && once.target == nil && once.state == .unsupported, "capture test stops; never claims message protection")
check(!once.consumeFrame(token: t, capturedAt: 100, now: 100.2, width: 100, height: 100, targetStillTrusted: true), "duplicate frame rejected")
let (timed, _) = ready(); timed.tick(now: 116)
check(!timed.wantsFrames && timed.target == nil, "no frame watchdog ends capture")
let (backward, _) = ready(); backward.tick(now: 99)
check(!backward.wantsFrames, "backwards time invalidates capture")
let (paused, _) = ready(); paused.stop(paused: true)
check(paused.state == .paused && !paused.wantsFrames && paused.target == nil, "pause clears selection")
// A weaker runtime gate must not permit policy/grant changes or raw launch.
let policy: [String: Any] = ["schemaVersion": 1, "bundleIdentifier": "devyashtanwar.whatsapp-blur-preview",
    "entitlements": ["com.apple.security.app-sandbox": true], "forbiddenCapabilities": ["network", "microphone", "camera", "location", "personal-files", "contacts", "calendar", "photos", "bluetooth", "usb", "accessibility", "keyboard", "clipboard", "secret-storage", "external-url-opening", "shell-execution", "persistent-settings"],
    "allowedResources": ["capability-policy.json", "source-manifest.json"], "captureScope": "explicit-picker-single-authenticated-whatsapp-window"]
let policyBytes = try! JSONSerialization.data(withJSONObject: policy)
func allowed(_ bundle: String? = "devyashtanwar.whatsapp-blur-preview", _ valid: Bool = true, _ hardened: Bool = true,
             _ grants: [String: Any] = ["com.apple.security.app-sandbox": true], _ bytes: Data? = policyBytes) -> Bool {
    PreviewPolicy.allows(bundleID: bundle, signatureValid: valid, hardened: hardened, entitlements: grants, data: bytes)
}
check(allowed(), "exact signed preview capability accepted")
check(!allowed(nil) && !allowed("devyashtanwar.whatsapp-privacy-cover") && !allowed("devyashtanwar.selective-blur-lab"), "wrong/raw bundle rejected")
check(!allowed(nil, false) && !allowed("devyashtanwar.whatsapp-blur-preview", true, false), "signature/runtime mandatory")
for key in ["com.apple.security.network.client", "com.apple.security.device.audio-input", "com.apple.security.accessibility", "com.apple.security.files.user-selected.read-only"] {
    check(!allowed("devyashtanwar.whatsapp-blur-preview", true, true, ["com.apple.security.app-sandbox": true, key: true]), "extra entitlement rejected \(key)")
}
check(!allowed("devyashtanwar.whatsapp-blur-preview", true, true, ["com.apple.security.app-sandbox": 1]), "integer sandbox value rejected")
var changedPolicy = policy; changedPolicy["captureScope"] = "display"
check(!allowed("devyashtanwar.whatsapp-blur-preview", true, true, ["com.apple.security.app-sandbox": true], try! JSONSerialization.data(withJSONObject: changedPolicy)), "widened capture policy rejected")
check(!allowed("devyashtanwar.whatsapp-blur-preview", true, true, ["com.apple.security.app-sandbox": true], nil), "missing policy rejected")
check(PickerScope.isSingleWindow(windowStyle: true, windowIDs: [42], ownerPIDs: [123], displayCount: 0, applicationPIDs: []), "picker single window allowed")
check(PickerScope.isSingleWindow(windowStyle: true, windowIDs: [42], ownerPIDs: [123], displayCount: 0, applicationPIDs: [123]), "matching window owner metadata allowed")
check(!PickerScope.isSingleWindow(windowStyle: false, windowIDs: [42], ownerPIDs: [123], displayCount: 0, applicationPIDs: []), "app/display style rejected")
check(!PickerScope.isSingleWindow(windowStyle: true, windowIDs: [42], ownerPIDs: [123], displayCount: 1, applicationPIDs: []), "display membership rejected")
check(!PickerScope.isSingleWindow(windowStyle: true, windowIDs: [42, 43], ownerPIDs: [123, 123], displayCount: 0, applicationPIDs: []), "multiple windows rejected")
check(!PickerScope.isSingleWindow(windowStyle: true, windowIDs: [42], ownerPIDs: [123], displayCount: 0, applicationPIDs: [124]), "other app membership rejected")
check(!PickerScope.isSingleWindow(windowStyle: true, windowIDs: [42], ownerPIDs: [123], displayCount: 0, applicationPIDs: [123, 123]), "multiple app membership rejected")
check(!PickerScope.isSingleWindow(windowStyle: true, windowIDs: [42], ownerPIDs: [], displayCount: 0, applicationPIDs: []), "missing owner rejected")
let stalePicker = CaptureSession(); let older = stalePicker.request(settings: BlurSettings(), now: 100)!
stalePicker.stop(); let newer = stalePicker.request(settings: BlurSettings(), now: 101)!
check(!stalePicker.accept(selected, token: older, now: 101) && stalePicker.state == .selecting, "old picker response cannot consume current request")
check(stalePicker.accept(selected, token: newer, now: 101), "current request remains usable after stale callback")
check(PickerEventPolicy.action(token: 7, currentToken: 7, selecting: false, hasStream: true, replacing: true) == .stopUnexpected, "active stream rejects unexpected picker change instead of ignoring it")
check(PickerEventPolicy.action(token: 6, currentToken: 7, selecting: false, hasStream: true, replacing: true) == .ignore, "old picker event cannot stop newer session")
check(PickerEventPolicy.action(token: 7, currentToken: 7, selecting: true, hasStream: false, replacing: false) == .acceptInitial, "initial picker selection accepted")
// Real lifecycle reducer: delayed start must remain a barrier to stop/reselection.
let starting = StreamLifetime(); let firstStart = starting.begin(now: 10)!
check(starting.begin(now: 10.1) == nil, "cannot overlap starts")
check(starting.requestStop(now: 10.2) == .none && starting.phase == .waitingForStart, "stop waits for pending start completion")
check(!starting.canBegin && starting.isStopping, "pending start/stop never reports stopped")
check(starting.requestStop(now: 10.3) == .none && starting.isStopping, "repeated stop retains stopping status")
check(starting.stopCompleted(token: firstStart, succeeded: true, now: 10.4) == .none && !starting.canBegin, "unsolicited early stop callback cannot reopen selection")
check(starting.startCompleted(token: firstStart, succeeded: true, now: 10.5) == .stop && starting.phase == .stopping, "late successful start issues exactly one serialized stop")
check(starting.startCompleted(token: firstStart, succeeded: true, now: 10.6) == .none, "duplicate start callback does not stop twice")
check(starting.stopCompleted(token: firstStart, succeeded: true, now: 10.7) == .release && starting.canBegin, "new selection only after confirmed stop")
let secondStart = starting.begin(now: 11)!
check(starting.startCompleted(token: firstStart, succeeded: true, now: 11.1) == .none && starting.phase == .starting, "old start cannot mutate new stream")
check(starting.stopCompleted(token: firstStart, succeeded: false, now: 11.2) == .none && starting.phase == .starting, "old stop cannot mutate new stream")
check(starting.startCompleted(token: secondStart, succeeded: true, now: 11.3) == .none && starting.phase == .running, "current start becomes running")
check(starting.requestStop(now: 11.4) == .stop && !starting.canBegin, "running stream requires confirmed stop")
check(starting.stopCompleted(token: secondStart, succeeded: false, now: 11.5) == .terminate && starting.phase == .failed, "stop failure cannot report stopped")
let failedStart = StreamLifetime(); let fs = failedStart.begin(now: 20)!
_ = failedStart.requestStop(now: 20.1)
check(failedStart.startCompleted(token: fs, succeeded: false, now: 20.2) == .release && failedStart.canBegin, "failed start releases without redundant stop")
let hanging = StreamLifetime(); _ = hanging.begin(now: 30); _ = hanging.requestStop(now: 30.1)
check(hanging.poll(now: 35) == .none, "stop deadline not premature")
_ = hanging.requestStop(now: 35)
check(hanging.poll(now: 35.2) == .terminate && !hanging.canBegin, "repeated stop cannot postpone shutdown deadline")
let invalidClock = StreamLifetime(); _ = invalidClock.begin(now: 40)
check(invalidClock.requestStop(now: .nan) == .terminate, "invalid lifecycle clock fails closed")
// Future production provider contract; positives are invented annotations, not real-layout evidence.
let binding = FrameBinding(session: 11, sequence: 2, windowID: 42, processID: 123,
                           processGeneration: 10, capturedAt: 100, width: 900, height: 700, scale: 2, windowFrame: CGRect(x: 100,y: 100,width: 450,height: 350))
let annotations = [DetectedRegion(id: 1, category: .sidebarPreview, bounds: CGRect(x: 90,y: 50,width: 180,height: 20)),
                   DetectedRegion(id: 2, category: .conversationMessage, bounds: CGRect(x: 400,y: 150,width: 300,height: 60)),
                   DetectedRegion(id: 3, category: .contactName, bounds: CGRect(x: 90,y: 80,width: 180,height: 20)),
                   DetectedRegion(id: 4, category: .avatar, bounds: CGRect(x: 30,y: 45,width: 45,height: 45))]
let annotated = RegionSnapshot(frame: binding, evidence: .supportedLayout, supportedCategories: BlurCategory.allCases,
                               regions: annotations, controls: [CGRect(x: 0,y: 650,width: 900,height: 50)])
func regionResult(_ input: RegionSnapshot, expected: FrameBinding = binding, settings: BlurSettings = BlurSettings(),
                  now: Double = 100.05, maxAge: Double = 0.1) -> RegionPlan {
    RegionValidator.validate(input, expected: expected, settings: settings, now: now, maxAge: maxAge)
}
for bits in 0..<16 {
    let settings = BlurSettings(sidebarPreviews: bits & 1 != 0, conversationMessages: bits & 2 != 0,
                                names: bits & 4 != 0, avatars: bits & 8 != 0)
    let result = regionResult(annotated, settings: settings)
    let wanted: [UInt64] = [(bits & 1 != 0 ? 1 : nil), (bits & 2 != 0 ? 2 : nil),
                            (bits & 4 != 0 ? 3 : nil), (bits & 8 != 0 ? 4 : nil)].compactMap { $0 }
    check(result.state == (bits == 0 ? .disabled : .ready) && result.regions.map(\.id) == wanted, "region selection combination \(bits)")
}
for evidence in [RegionEvidence.textGeometryOnly, .syntheticFixture] {
    var x = annotated; x.evidence = evidence
    check(regionResult(x).state == .unsupported && regionResult(x).regions.isEmpty, "generic text or lab geometry cannot become real protection")
}
for change in 0..<11 {
    var x = annotated
    switch change {
    case 0: x.frame.session = 12
    case 1: x.frame.sequence = 1
    case 2: x.frame.windowID = 43
    case 3: x.frame.processID = 124
    case 4: x.frame.processGeneration = 11
    case 5: x.frame.width = 899
    case 6: x.frame.height = 699
    case 7: x.frame.scale = 1
    case 8: x.frame.capturedAt = 99.99
    case 9: x.frame.windowFrame.origin.x += 1
    default: x.frame.windowFrame.size.width += 1
    }
    check(regionResult(x).state == .mismatch && regionResult(x).regions.isEmpty, "reject mismatched pixel/geometry provenance \(change)")
}
check(regionResult(annotated, now: 100.11).state == .stale, "age budget enforced")
check(regionResult(annotated, now: 99).state == .stale, "future captured frame rejected")
check(regionResult(annotated, now: .nan).state == .invalid, "nonfinite current time rejected")
check(regionResult(annotated, maxAge: 0).state == .invalid, "invalid freshness budget rejected")
var noLayout = annotated; noLayout.supportedCategories = [.sidebarPreview]
check(regionResult(noLayout).state == .unsupported, "partial support cannot claim both message categories")
var duplicate = annotated; duplicate.regions.append(annotations[0])
check(regionResult(duplicate).state == .invalid, "duplicate region IDs rejected")
for bounds in [CGRect(x: -1,y: 5,width: 30,height: 20), CGRect(x: 5,y: 5,width: 0,height: 20),
               CGRect(x: 890,y: 5,width: 30,height: 20), CGRect(x: CGFloat.nan,y: 5,width: 30,height: 20),
               CGRect(x: 5,y: 660,width: 30,height: 20)] {
    var x = annotated; x.regions = [DetectedRegion(id: 1, category: .sidebarPreview, bounds: bounds)]
    check(regionResult(x).state == .invalid, "invalid or control-overlapping mask rejected")
}
var identityOverlap = annotated
identityOverlap.regions = [DetectedRegion(id: 1, category: .sidebarPreview, bounds: CGRect(x: 90,y: 50,width: 180,height: 50)), annotations[2]]
check(regionResult(identityOverlap).state == .invalid, "preview cannot conceal disabled name category")
var badFrame = binding; badFrame.width = 0
var badSnapshot = annotated; badSnapshot.frame = badFrame
check(regionResult(badSnapshot, expected: badFrame).state == .invalid, "invalid frame dimensions rejected")
// External frame boundaries never inherit a hover from unrelated pixels.
let external = ExternalHover()
let externalItem = DetectedRegion(id: 800,category: .conversationMessage,bounds: CGRect(x: 20,y: 20,width: 80,height: 40))
let revealSettings = BlurSettings(conversationHover: true)
external.newFrame(sequence: 1,now: 200)
check(external.pointer(CGPoint(x: 25,y: 25),region: externalItem,settings: revealSettings,now: 200.1) == nil,"external reveal waits for settled frame")
check(external.tick(now: 200.2) == nil,"timer cannot reveal after frame settles")
check(external.pointer(CGPoint(x: 26,y: 25),region: externalItem,settings: revealSettings,now: 200.21) == 800,"post-frame pointer movement recovers without focus switch")
external.newFrame(sequence: 2,now: 200.22)
check(external.revealedID == nil,"new frame immediately revokes sharp item")
check(external.pointer(CGPoint(x: 26,y: 25),region: externalItem,settings: revealSettings,now: 200.5) == nil,"stationary pointer cannot reveal changed content")
check(external.pointer(CGPoint(x: 27,y: 25),region: externalItem,settings: revealSettings,now: 200.51) == 800,"hover recovers after scroll without leaving chat")
check(external.tick(now: 202.52) == nil,"external lease expires")
check(external.pointer(CGPoint(x: 28,y: 25),region: externalItem,settings: revealSettings,now: 202.53) == nil,"expired lease does not rearm while lingering")
check(external.pointer(CGPoint(x: 200,y: 200),region: nil,settings: revealSettings,now: 202.54) == nil,"exit remains blurred")
check(external.pointer(CGPoint(x: 29,y: 25),region: externalItem,settings: revealSettings,now: 202.55) == 800,"reenter intentionally rearms lease")
let identityItem = DetectedRegion(id: 900,category: .contactName,bounds: externalItem.bounds)
check(external.pointer(CGPoint(x: 30,y: 25),region: identityItem,settings: BlurSettings(names: true,conversationHover: true),now: 202.56) == nil,"identity never acquires hover")
check(external.pointer(CGPoint(x: 300,y: 200),region: externalItem,settings: revealSettings,now: 202.57) == nil,"caller hit-test error cannot reveal distant region")
external.newFrame(sequence: 1,now: 202.6)
check(external.pointer(CGPoint(x: 31,y: 25),region: externalItem,settings: revealSettings,now: 203) == nil,"out-of-order frame invalidates hover eligibility")
let continuous = CaptureSession(continuous: true)
let ct = continuous.request(settings: BlurSettings(),now: 300)!
check(continuous.accept(SelectionDescriptor(windowID: 99,pid: 99,generation: 30,bundleIdentifier: "net.whatsapp.WhatsApp",singleWindow: true,trusted: true),token: ct,now: 300),"continuous selected target authenticated")
check(continuous.consumeFrame(token: ct,capturedAt: 300.1,now: 300.2,width: 900,height: 700,targetStillTrusted: true),"continuous frame accepted")
check(continuous.wantsFrames,"live candidate continues after first frame")
continuous.stop()
check(!continuous.consumeFrame(token: ct,capturedAt: 300.3,now: 300.4,width: 900,height: 700,targetStillTrusted: true),"stopped live session rejects late frame")
let publication = PublicationGate()
let rev = publication.revision
check(publication.accept(revision: rev,frame: binding,currentWindow: binding.windowFrame,frontmost: true,now: 100.1),"current paired frame can publish")
check(!publication.accept(revision: rev,frame: binding,currentWindow: binding.windowFrame,frontmost: true,now: 100.2),"duplicate worker publication rejected")
publication.reset()
check(!publication.accept(revision: rev,frame: binding,currentWindow: binding.windowFrame,frontmost: true,now: 100.2),"late worker cannot revive stopped/settings-changed session")
check(!publication.accept(revision: publication.revision,frame: binding,currentWindow: nil,frontmost: true,now: 100.2),"missing window rejected")
check(!publication.accept(revision: publication.revision,frame: binding,currentWindow: binding.windowFrame.offsetBy(dx: 1,dy: 0),frontmost: true,now: 100.2),"moved window needs freshly bound image")
check(!publication.accept(revision: publication.revision,frame: binding,currentWindow: binding.windowFrame,frontmost: false,now: 100.2),"background target cannot receive overlay")
check(!publication.accept(revision: publication.revision,frame: binding,currentWindow: binding.windowFrame,frontmost: true,now: 102),"slow worker is not published")
check(!publication.accept(revision: publication.revision,frame: binding,currentWindow: binding.windowFrame,frontmost: true,now: .nan),"invalid worker time rejected")
// Final review regressions: a delayed first sample establishes intent, never invents it.
for reset in ["selection", "settings reenable", "focus return"] {
    let stationary = ExternalHover(); stationary.newFrame(sequence: 1,now: 400)
    check(stationary.pointer(CGPoint(x: 30,y: 25),region: externalItem,settings: revealSettings,now: 400.5) == nil,"delayed first stationary sample after \(reset) is only a baseline")
    check(stationary.pointer(CGPoint(x: 31,y: 25),region: externalItem,settings: revealSettings,now: 400.6) == 800,"subsequent displacement after \(reset) intentionally reveals")
}
let occluded = ExternalHover(); occluded.newFrame(sequence: 1,now: 500)
_ = occluded.pointer(CGPoint(x: 25,y: 25),region: externalItem,settings: revealSettings,now: 500.1)
check(occluded.pointer(CGPoint(x: 26,y: 25),region: externalItem,settings: revealSettings,now: 500.2) == 800,"occlusion fixture starts with an intentional lease")
let oldRevealRevision = occluded.revision
occluded.visibilityChanged(false,now: 500.21)
check(occluded.revealedID == nil,"observed occlusion revokes active reveal")
occluded.visibilityChanged(true,now: 500.22)
check(!occluded.permitsCompletion(revision: oldRevealRevision,item: 800,now: 500.23),"asynchronous pre-occlusion reveal cannot publish after recovery")
check(occluded.pointer(CGPoint(x: 26,y: 25),region: externalItem,settings: revealSettings,now: 500.5) == nil,"stationary recovery stays blurred")
check(occluded.pointer(CGPoint(x: 27,y: 25),region: externalItem,settings: revealSettings,now: 500.51) == 800,"fresh movement recovers after occlusion")
check(!occluded.permitsCompletion(revision: oldRevealRevision,item: 800,now: 500.52),"old result cannot borrow a newly acquired same-item lease")
check(occluded.permitsCompletion(revision: occluded.revision,item: 800,now: 500.53),"current reveal result can publish")
let selectionBinding = SelectionDescriptor(windowID: binding.windowID,pid: binding.processID,generation: binding.processGeneration,bundleIdentifier: "net.whatsapp.WhatsApp",singleWindow: true,trusted: true)
check(TargetBinding.isCurrent(binding,selection: selectionBinding,token: binding.session,currentGeneration: binding.processGeneration,processStillCurrent: true),"full current target binding accepted")
check(!TargetBinding.isCurrent(binding,selection: selectionBinding,token: binding.session,currentGeneration: binding.processGeneration+1,processStillCurrent: false),"PID/window/bounds reuse with changed generation rejected before presentation")
check(!TargetBinding.isCurrent(binding,selection: selectionBinding,token: binding.session+1,currentGeneration: binding.processGeneration,processStillCurrent: true),"late selected-session frame rejected before presentation")
check(!TargetBinding.isCurrent(binding,selection: nil,token: binding.session,currentGeneration: binding.processGeneration,processStillCurrent: true),"stopped selection cannot present cached pixels")
check(!TargetBinding.isCurrent(binding,selection: selectionBinding,token: binding.session,currentGeneration: binding.processGeneration+1,processStillCurrent: true),"generation mismatch independently rejects publication")
check(!TargetBinding.isCurrent(binding,selection: selectionBinding,token: binding.session,currentGeneration: binding.processGeneration,processStillCurrent: false),"lost process continuity independently rejects publication")
let quiet = CaptureSession(continuous: true)
let qt = quiet.request(settings: BlurSettings(),now: 600)!
_ = quiet.accept(selectionBinding,token: qt,now: 600)
_ = quiet.consumeFrame(token: qt,capturedAt: 600.1,now: 600.2,width: 900,height: 700,targetStillTrusted: true)
quiet.tick(now: 630)
check(quiet.wantsFrames,"unchanged selected window is not declared disconnected after three seconds")
check(quiet.consumeFrame(token: qt,capturedAt: 630.1,now: 630.2,width: 900,height: 700,targetStillTrusted: true),"fresh update after long static interval remains accepted")
let waiting = CaptureSession(continuous: true)
let wt = waiting.request(settings: BlurSettings(),now: 700)!
_ = waiting.accept(selectionBinding,token: wt,now: 700)
_ = waiting.observeIdle(token: wt,now: 714,targetStillTrusted: true)
waiting.tick(now: 716)
check(!waiting.wantsFrames,"idle without an initial image cannot extend initial-frame deadline")
let preparing = PublicationGate()
check(preparing.prepare(revision: preparing.revision,frame: binding,currentWindow: binding.windowFrame,now: 100.1),"selected image can be prepared while picker/settings has focus")
check(!preparing.prepare(revision: preparing.revision,frame: binding,currentWindow: binding.windowFrame,now: 100.2),"duplicate preparation rejected")
print("\(count) integration assertions, \(failures) failures")
if failures > 0 { exit(1) }

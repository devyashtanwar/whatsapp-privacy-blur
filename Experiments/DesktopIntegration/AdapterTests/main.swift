import Foundation
import CaptureAdapter
import ScreenCaptureKit
var failures = 0
var count = 0
func check(_ value: @autoclosure () -> Bool, _ message: String) {
    count += 1; if !value() { failures += 1; print("FAIL: \(message)") }
}
if let configuration = CaptureConfiguration.make(width: 1200, height: 800) {
    check(configuration.width == 1200 && configuration.height == 800, "native frame dimensions preserved")
    check(configuration.queueDepth == 2, "bounded OS capture queue")
    check(!configuration.capturesAudio && !configuration.captureMicrophone, "no audio or microphone")
    check(!configuration.showsCursor, "no cursor image in input")
} else { check(false, "valid window dimensions") }
for (w, h) in [(0.0, 100.0), (-1, 100), (100, .nan), (.infinity, 100), (4097, 100), (100, 4097)] {
    check(CaptureConfiguration.make(width: w, height: h) == nil, "reject unsupported dimensions before capture")
}
check(FrameSamplePolicy.classify(.started,sampleValid: true,dataReady: true,hasImage: true) == .image,"usable initial frame accepted")
check(FrameSamplePolicy.classify(.started,sampleValid: true,dataReady: false,hasImage: true) == .ignored,"unready initial image rejected")
check(FrameSamplePolicy.classify(.started,sampleValid: true,dataReady: true,hasImage: false) == .ignored,"initial status alone is not image evidence")
check(FrameSamplePolicy.classify(.complete,sampleValid: true,dataReady: true,hasImage: true) == .image,"complete image accepted")
check(FrameSamplePolicy.classify(.idle,sampleValid: true,dataReady: false,hasImage: false) == .unchanged,"idle requires no invented image")
print("\(count) capture configuration assertions, \(failures) failures")
if failures > 0 { exit(1) }

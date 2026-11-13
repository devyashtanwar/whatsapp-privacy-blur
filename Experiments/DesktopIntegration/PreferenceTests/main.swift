import Foundation
import IntegrationCore
var count = 0,failed = 0
func check(_ value:Bool,_ text:String) { count += 1;if !value { failed += 1;print("FAIL: \(text)") } }
final class MemoryIO:PrivatePreferenceIO {
    var data:Data?
    var redirected = false
    var cannotWrite = false
    var path:URL?
    func canonical(_ url:URL) -> Bool { !redirected }
    func read(_ url:URL) throws -> Data? { path = url;return data }
    func write(_ data:Data,to url:URL) throws { if cannotWrite { throw AutoPreferences.Invalid.schema };path = url;self.data = data }
}
let io = MemoryIO() // Never read/write the default disk implementation.
let fake = PreferenceStore(io:io)
check((try? fake.load())?.automaticEnabled == false,"first launch requires explicit enable")
try! fake.save(AutoPreferences(automaticEnabled:true))
check((try? fake.load())?.automaticEnabled == true,"enabled setting persists")
check(io.path?.lastPathComponent == "preferences.json" && io.path!.path.contains("Library/Application Support/WhatsAppBlur/"),"fixed non-user-selected path")
try! fake.save(AutoPreferences())
check((try? fake.load())?.automaticEnabled == false,"Pause persists across restart")
let saved = io.data;io.cannotWrite = true
check((try? fake.save(AutoPreferences(automaticEnabled:true))) == nil && io.data == saved,"write failure propagates without replacing old state")
io.redirected = true
check((try? fake.load()) == nil,"redirected path rejects reading")
check((try? fake.save(AutoPreferences())) == nil,"redirected path rejects writing")
io.redirected = false;io.data = Data("corrupt".utf8)
check((try? fake.load()) == nil,"corrupt file never enables capture")
print("\(count) private preference assertions, \(failed) failures")
if failed > 0 { exit(1) }

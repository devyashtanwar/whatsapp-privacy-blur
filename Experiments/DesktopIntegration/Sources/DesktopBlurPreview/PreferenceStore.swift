import Foundation
import IntegrationCore

/// Injectable I/O for failure tests; the store itself always chooses one fixed private path.
protocol PrivatePreferenceIO {
    func canonical(_ url:URL) -> Bool
    func read(_ url:URL) throws -> Data?
    func write(_ data:Data,to url:URL) throws
}
private struct DiskPreferenceIO:PrivatePreferenceIO {
    func canonical(_ url:URL) -> Bool { url.resolvingSymlinksInPath().standardizedFileURL == url.standardizedFileURL }
    func read(_ url:URL) throws -> Data? {
        guard FileManager.default.fileExists(atPath:url.path) else { return nil }
        let attributes = try FileManager.default.attributesOfItem(atPath:url.path)
        guard attributes[.type] as? FileAttributeType == .typeRegular,
              ((attributes[.size] as? NSNumber)?.intValue ?? 2049) <= 2048 else { throw AutoPreferences.Invalid.schema }
        return try Data(contentsOf:url)
    }
    func write(_ data:Data,to url:URL) throws {
        let folder = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at:folder,withIntermediateDirectories:true,attributes:[.posixPermissions:0o700])
        guard canonical(folder),canonical(url) else { throw AutoPreferences.Invalid.schema }
        try data.write(to:url,options:[.atomic])
        try FileManager.default.setAttributes([.posixPermissions:0o600],ofItemAtPath:url.path)
    }
}
final class PreferenceStore {
    private let io:PrivatePreferenceIO
    private let root = URL(fileURLWithPath:NSHomeDirectory(),isDirectory:true)
    init(io:PrivatePreferenceIO? = nil) { self.io = io ?? DiskPreferenceIO() }
    private var folder:URL { root.appendingPathComponent("Library/Application Support/WhatsAppBlur",isDirectory:true) }
    private var file:URL { folder.appendingPathComponent("preferences.json") }
    private func checkedPath() throws {
        guard io.canonical(root),io.canonical(folder),io.canonical(file) else { throw AutoPreferences.Invalid.schema }
    }
    func load() throws -> AutoPreferences {
        try checkedPath()
        guard let data = try io.read(file) else { return AutoPreferences() }
        return try AutoPreferences.decode(data)
    }
    func save(_ preferences:AutoPreferences) throws {
        try checkedPath();try io.write(preferences.encoded(),to:file)
    }
}

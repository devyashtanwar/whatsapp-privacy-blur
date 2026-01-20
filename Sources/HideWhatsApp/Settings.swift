import Foundation

final class Settings {
    static let shared = Settings()

    private let defaults = UserDefaults.standard

    private enum Key {
        static let overlayEnabled = "overlayEnabled"
        static let overlayWidth = "overlayWidth"
        static let autoDetectWidth = "autoDetectWidth"
        static let blurIntensity = "blurIntensity"
        static let launchAtLogin = "launchAtLogin"
    }

    var overlayEnabled: Bool {
        get { defaults.bool(forKey: Key.overlayEnabled) }
        set {
            defaults.set(newValue, forKey: Key.overlayEnabled)
            NotificationCenter.default.post(name: .settingsChanged, object: nil)
        }
    }

    var overlayWidth: CGFloat {
        get {
            let value = defaults.double(forKey: Key.overlayWidth)
            return value > 0 ? value : 308
        }
        set {
            defaults.set(newValue, forKey: Key.overlayWidth)
            NotificationCenter.default.post(name: .settingsChanged, object: nil)
        }
    }

    var autoDetectWidth: Bool {
        get {
            if defaults.object(forKey: Key.autoDetectWidth) == nil {
                return true // Default to true
            }
            return defaults.bool(forKey: Key.autoDetectWidth)
        }
        set {
            defaults.set(newValue, forKey: Key.autoDetectWidth)
            NotificationCenter.default.post(name: .settingsChanged, object: nil)
        }
    }

    var blurIntensity: String {
        get { defaults.string(forKey: Key.blurIntensity) ?? "medium" }
        set {
            defaults.set(newValue, forKey: Key.blurIntensity)
            NotificationCenter.default.post(name: .settingsChanged, object: nil)
        }
    }

    var launchAtLogin: Bool {
        get { defaults.bool(forKey: Key.launchAtLogin) }
        set {
            defaults.set(newValue, forKey: Key.launchAtLogin)
            LaunchAtLogin.setEnabled(newValue)
        }
    }

    private init() {
        // Register defaults
        defaults.register(defaults: [
            Key.overlayEnabled: true,
            Key.overlayWidth: 308.0,
            Key.autoDetectWidth: true,
            Key.blurIntensity: "medium"
        ])
    }
}

extension Notification.Name {
    static let settingsChanged = Notification.Name("settingsChanged")
}

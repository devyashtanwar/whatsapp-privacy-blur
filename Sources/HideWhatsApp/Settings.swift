import Foundation
import PrivacyCore

final class Settings {
    static let shared = Settings()
    private let defaults = UserDefaults.standard

    var configuration: CoverConfiguration {
        CoverConfiguration(enabled: overlayEnabled, fullWindow: fullWindow,
                           hoverReveal: hoverReveal, sidebarWidth: overlayWidth)
    }

    var overlayEnabled: Bool {
        get { defaults.bool(forKey: "overlayEnabled") }
        set { defaults.set(newValue, forKey: "overlayEnabled"); changed() }
    }
    var fullWindow: Bool {
        get { defaults.bool(forKey: "fullWindow") }
        set { defaults.set(newValue, forKey: "fullWindow"); changed() }
    }
    var hoverReveal: Bool {
        get { defaults.bool(forKey: "hoverReveal") }
        set { defaults.set(newValue, forKey: "hoverReveal"); changed() }
    }
    var overlayWidth: CGFloat {
        get { CoverConfiguration(sidebarWidth: defaults.double(forKey: "overlayWidth")).sidebarWidth }
        set {
            defaults.set(Double(CoverConfiguration(sidebarWidth: newValue).sidebarWidth), forKey: "overlayWidth")
            changed()
        }
    }

    private init() {
        defaults.register(defaults: [
            "overlayEnabled": true, "fullWindow": true,
            "hoverReveal": false, "overlayWidth": 308.0
        ])
    }

    private func changed() {
        NotificationCenter.default.post(name: .settingsChanged, object: nil)
    }
}

extension Notification.Name {
    static let settingsChanged = Notification.Name("settingsChanged")
}

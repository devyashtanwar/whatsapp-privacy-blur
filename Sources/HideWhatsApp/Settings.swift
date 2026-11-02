import Foundation
import PrivacyCore

final class Settings {
    static let shared = Settings()
    private let session = SessionSettings()
    var configuration: CoverConfiguration { session.configuration }

    var overlayEnabled: Bool {
        get { session.enabled }
        set { session.enabled = newValue; changed() }
    }
    var fullWindow: Bool {
        get { session.fullWindow }
        set { session.fullWindow = newValue; changed() }
    }
    var hoverReveal: Bool {
        get { session.hoverReveal }
        set { session.hoverReveal = newValue; changed() }
    }
    var overlayWidth: CGFloat {
        get { session.configuration.sidebarWidth }
        set { session.width = CoverConfiguration(sidebarWidth: newValue).sidebarWidth; changed() }
    }
    private func changed() { NotificationCenter.default.post(name: .settingsChanged, object: nil) }
}
extension Notification.Name {
    static let settingsChanged = Notification.Name("settingsChanged")
}

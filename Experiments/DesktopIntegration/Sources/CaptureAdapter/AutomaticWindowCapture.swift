import ScreenCaptureKit
import IntegrationCore
/// No public arbitrary-window initializer: discovery plus shared offline validation are mandatory.
public enum AutomaticWindowCapture {
    public static func start(_ target:DiscoveredWhatsAppWindow,capture:SelectedWindowCapture,settings:BlurSettings) {
        guard ScreenPermission.preflight(),target.stillCurrent else { capture.stop(message:"Permission or WhatsApp process changed. No blur is active.");return }
        let filter = SCContentFilter(desktopIndependentWindow:target.nativeWindow)
        capture.startAutomatically(filter:filter,settings:settings)
    }
}

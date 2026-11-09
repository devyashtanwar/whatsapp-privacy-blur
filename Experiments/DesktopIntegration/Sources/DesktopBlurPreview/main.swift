import AppKit

// Raw/unbundled launch cannot initialize UI, query target apps or open the picker.
guard confinementAllowed() else {
    fputs("Use the verified, signed WhatsApp Blur Integration Preview bundle.\n", stderr)
    exit(1)
}
let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let delegate = PreviewApp(); app.delegate = delegate; app.run()

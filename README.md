# WhatsApp Privacy Blur 🔒

<p align="center">
  <img src="https://img.shields.io/badge/macOS-13.0+-blue?style=flat-square&logo=apple" alt="macOS 13.0+">
  <img src="https://img.shields.io/badge/Swift-6.0-orange?style=flat-square&logo=swift" alt="Swift 6.0">
  <img src="https://img.shields.io/badge/license-MIT-green?style=flat-square" alt="MIT License">
</p>

<p align="center">
  <strong>Keep your WhatsApp chats private with an intelligent blur overlay.</strong><br>
  A lightweight macOS menu bar app that automatically blurs your WhatsApp sidebar.
</p>

---

## ✨ Features

- **🎯 Smart Blur** - Automatically blurs chat list and header for instant privacy
- **👆 Hover to Reveal** - Smooth fade animation reveals content on hover
- **📏 Auto-Detect Width** - Uses Accessibility APIs to detect sidebar width
- **🎨 Blur Intensity** - Choose from Light, Medium, or Heavy blur
- **⚙️ Manual Control** - Adjust overlay width with slider (200-500px)
- **🚀 Launch at Login** - Auto-start on macOS login (macOS 13+)
- **🌟 Menu Bar App** - Lives in your menu bar, no dock icon clutter

## 📸 Preview

```
┌────────────────────────────────────────┐
│ 🔒 WhatsApp Privacy Blur               │
├────────────────────────────────────────┤
│ ✓ Enabled                              │
│ ✓ Auto-detect Width                    │
│   Width: 308px [━━━━━━━━━━━━━━━]      │
│ ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ │
│   Blur Intensity      › Medium ✓       │
│ ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ │
│ ✓ Launch at Login                      │
│ ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ │
│   Quit                                 │
└────────────────────────────────────────┘
```

## 🚀 Installation

### Easy Install (Recommended)

```bash
./install.sh
```

This builds the release binary and installs it as a proper macOS app to `/Applications/WhatsApp Privacy Blur.app`.

### Manual Build

```bash
swift build -c release
.build/release/HideWhatsApp
```

## 🔧 Requirements

- macOS 13.0 or later
- Accessibility permission (required for window detection)
- WhatsApp Desktop app

## 📖 Usage

1. **Launch the app** - Find it via Spotlight or in `/Applications`
2. **Grant accessibility permission** - Required for detecting WhatsApp window position
3. **Open WhatsApp** - Blur overlay appears automatically
4. **Hover to reveal** - Move cursor over blur to temporarily reveal content
5. **Configure** - Click menu bar icon for settings

## ⚙️ Configuration

### Menu Bar Options

| Option | Description |
|--------|-------------|
| **Enabled** | Toggle blur on/off (⌘+E) |
| **Auto-detect Width** | Automatically detect sidebar width via Accessibility APIs |
| **Width Slider** | Manually adjust overlay width (200-500px) |
| **Blur Intensity** | Choose Light, Medium, or Heavy blur effect |
| **Launch at Login** | Auto-start on macOS login (uses SMAppService) |
| **Quit** | Exit the app (⌘+Q) |

### Settings Persistence

All settings are saved automatically via `UserDefaults` and persist across app restarts.

## 🏗️ Architecture

```
Sources/HideWhatsApp/
├── main.swift              # Entry point
├── AppDelegate.swift       # App lifecycle
├── StatusBar.swift         # Menu bar UI
├── Settings.swift          # User preferences
├── LaunchAtLogin.swift     # SMAppService wrapper
├── BlurOverlay.swift       # Blur window rendering
└── WhatsAppMonitor.swift   # Window position tracking
```

## 🔐 Privacy

- **No data collection** - Everything runs locally
- **No network requests** - Zero external communication
- **No analytics** - Your privacy is paramount
- **Open source** - Audit the code yourself

## 🛠️ Development

### Build

```bash
swift build
```

### Run (Debug)

```bash
swift run
```

### Clean

```bash
swift package clean
```

## 📝 Changelog

See [CHANGELOG.md](CHANGELOG.md) for version history.

### Latest (v1.2.0)

- ✅ Proper macOS app bundle
- ✅ Launch at Login support
- ✅ Install script for easy setup

## 🤝 Contributing

Contributions welcome! Feel free to open issues or submit PRs.

## 📄 License

MIT License - See [LICENSE](LICENSE) for details.

## 🙏 Acknowledgments

Built with Swift and macOS AppKit. Uses:
- `NSWindow` for overlay rendering
- Accessibility APIs for window detection
- `SMAppService` for login item registration
- `UserDefaults` for settings persistence

---

<p align="center">
  Made with ❤️ for privacy-conscious WhatsApp users
</p>

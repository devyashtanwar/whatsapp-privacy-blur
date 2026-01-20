# Changelog

## [1.2.0] - 2026-01-20

### Added
- Install script (`install.sh`) - builds and installs proper macOS app bundle to /Applications
- Launch at Login - auto-start on login via SMAppService (macOS 13+)
- "Launch at Login" toggle in menu bar

### Changed
- App now runs as proper .app bundle ("WhatsApp Privacy Blur.app")
- Searchable via Spotlight

## [1.1.0] - 2026-01-20

### Added
- Header blur overlay (contact name area now blurred separately)
- Blur intensity setting (Light/Medium/Heavy) via menu bar submenu
- Independent reveal: hover sidebar reveals only sidebar, hover header reveals only header

### Fixed
- Solid block appearance replaced with proper blur effect (configurable materials)
- Hover flickering: polling no longer resets alpha when hovering
- Click-through: clicks now pass through to WhatsApp when hovering over overlay
- Default width changed from 320px to 308px for better alignment

### Changed
- Blur overlay uses global mouse event monitor instead of tracking area
- Architecture now supports multiple independent blur regions

## [1.0.0] - 2026-01-20

### Added
- Initial release
- Menu bar app with blur overlay for WhatsApp chat list
- Hover-to-reveal functionality with smooth fade animation
- Auto-detect sidebar width using Accessibility APIs
- Manual width adjustment slider (200-500px)
- Toggle enable/disable from menu bar
- Persisted settings via UserDefaults
- Accessibility permission prompt on first launch

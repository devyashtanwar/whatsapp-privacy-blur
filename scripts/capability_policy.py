"""Offline policy checks. These guardrails do not replace source review or OS confinement."""
import json
from pathlib import Path
import re

BUNDLE_ID = "devyashtanwar.whatsapp-privacy-cover"
CAPABILITIES = ["network", "microphone", "camera", "location", "personal-files", "contacts",
    "calendar", "photos", "bluetooth", "usb", "screen-capture", "accessibility",
    "keyboard", "clipboard", "secret-storage", "external-url-opening",
    "shell-execution", "persistent-settings"]
RESOURCES = ["capability-policy.json", "source-manifest.json"]
REQUIRED_POLICY = dict(schemaVersion=1, bundleIdentifier=BUNDLE_ID,
    entitlements={"com.apple.security.app-sandbox": True},
    forbiddenCapabilities=CAPABILITIES, allowedResources=RESOURCES)

SENSITIVE_SYMBOLS = [
    r"AXUIElement|AXIsProcessTrusted|CGWindowListCreateImage|CGDisplayCreateImage|SCStream|SCScreenshotManager",
    r"NSURLSession|NWConnection|WKWebView|WebView|NSSharingService|NSAppleScript",
    r"AVCapture|CLLocationManager|CNContactStore|EKEventStore|PHPhotoLibrary|NSPasteboard",
    r"SecItem(?:Add|Update|Delete|CopyMatching)|NSOpenPanel|NSSavePanel|NSPrintOperation|IOBluetooth|IOUSB",
    r"\b_(?:socket|connect|bind|listen|sendto|getaddrinfo|execve|posix_spawn|system|popen|dlopen|dlsym)\b"
]
SOURCE_PATTERNS = [
    r"\bimport\s+(?:Network|WebKit|AVFoundation|CoreLocation|Contacts|EventKit|Photos|CoreBluetooth|IOKit)\b",
    r"\b(?:URLSession|CFHTTPMessage|CFSocket|NWConnection|WKWebView|NSSharingService|NSAppleScript|NSUserAppleScriptTask|NSOpenPanel|NSSavePanel|NSPasteboard|UserDefaults|AVCaptureDevice|CLLocationManager|SecItemCopyMatching)\b",
    r"\.(?:open|openURL|openFile|loadHTMLString|loadRequest)\s*\(",
    r"\b(?:Process|NSTask|NSClassFromString|socket|connect|bind|listen|sendto|getaddrinfo|execve|posix_spawn|system|popen|dlopen|dlsym)\s*\(",
    r"addGlobalMonitorForEvents|CGEventTapCreate|NSPrintOperation|kSecCSAllowNetworkAccess|SecTrustSetNetworkFetchAllowed"
]

def validate_policy(document):
    if document != REQUIRED_POLICY or document.get("entitlements", {}).get("com.apple.security.app-sandbox") is not True:
        raise ValueError("Capability policy differs from the compiled offline-only budget")

def validate_metadata(info, entitlements):
    if info.get("CFBundleIdentifier") != BUNDLE_ID or info.get("CFBundleExecutable") != "HideWhatsApp":
        raise ValueError("Unexpected app identity")
    if set(entitlements) != {"com.apple.security.app-sandbox"} or entitlements["com.apple.security.app-sandbox"] is not True:
        raise ValueError("Only the boolean sandbox entitlement is permitted")
    for key in info:
        if key.endswith("UsageDescription") or key in {"CFBundleURLTypes", "CFBundleDocumentTypes", "NSServices", "NSExtension"}:
            raise ValueError("Unexpected permission request or handler: " + key)

def audit_runtime_sources(repo):
    repo = Path(repo)
    validate_policy(json.loads((repo / "Security/CapabilityPolicy.json").read_text()))
    violations = []
    package = repo / "Package.swift"
    if package.exists() and re.search(r"\.(?:package|binaryTarget|plugin|unsafeFlags)\s*\(", package.read_text()):
        violations.append("External packages, plugins, binaries and unsafe build flags are not permitted")
    for path in sorted((repo / "Sources").rglob("*")):
        if path.is_symlink():
            violations.append(str(path) + ": symbolic link")
        elif path.is_file():
            if path.suffix != ".swift":
                violations.append(str(path) + ": unexpected runtime input")
                continue
            source = path.read_text()
            validation_calls = re.findall(r"\bSec(?:Static)?CodeCheckValidity\s*\(", source)
            validation_flags = re.findall(r"\bSec(?:Static)?CodeCheckValidity\s*\([^;]*?SecCSFlags\(rawValue:\s*([^)]+)\)", source, re.S)
            if len(validation_calls) != len(validation_flags) or any(
                "SecCSFlags.noNetworkAccess.rawValue" not in flags or "kSecCSStrictValidate" not in flags
                for flags in validation_flags
            ):
                violations.append(str(path.relative_to(repo)) + ": code validation must explicitly be strict and offline")
            for pattern in SOURCE_PATTERNS:
                if re.search(pattern, source):
                    violations.append(str(path.relative_to(repo)) + ": forbidden API family " + pattern)
    if violations:
        raise ValueError("\n".join(violations))

import json
import plistlib
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch
sys.path.insert(0, str(Path(__file__).parents[2] / "scripts"))
from verify_app import verify_app

class CapabilityArtifactTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(); self.addCleanup(self.temp.cleanup)
        self.app = Path(self.temp.name) / "Fixture.app"
        (self.app / "Contents/MacOS").mkdir(parents=True)
        (self.app / "Contents/Resources").mkdir()
        (self.app / "Contents/MacOS/HideWhatsApp").write_bytes(bytes.fromhex("cffaedfe") + b"fixture")
        self.info = {"CFBundleIdentifier": "devyashtanwar.whatsapp-privacy-cover", "CFBundleExecutable": "HideWhatsApp"}
        self.entitlements = {"com.apple.security.app-sandbox": True}
        self.symbols = ""
        self.flags = "flags=0x10002(adhoc,runtime)"
        self.libs = "binary:\n /usr/lib/libSystem.B.dylib (compatibility version 1.0.0)\n"
        policy = Path(__file__).parents[2] / "Security/CapabilityPolicy.json"
        (self.app / "Contents/Resources/capability-policy.json").write_bytes(policy.read_bytes())
        (self.app / "Contents/Resources/source-manifest.json").write_text("{}")
    def verify(self):
        (self.app / "Contents/Info.plist").write_bytes(plistlib.dumps(self.info))
        def run(command, **kw):
            out = plistlib.dumps(self.entitlements) if "--entitlements" in command else ""
            return subprocess.CompletedProcess(command, 0, stdout=out, stderr=self.flags)
        def output(command, **kw):
            return self.symbols if command[0] == "nm" else self.libs
        with patch("verify_app.subprocess.run", side_effect=run), patch("verify_app.subprocess.check_output", side_effect=output):
            verify_app(self.app)
    def test_clean_fixture_passes(self):
        self.verify()
    def test_sensitive_usage_descriptions_rejected(self):
        for key in ["NSMicrophoneUsageDescription", "NSCameraUsageDescription", "NSLocationUsageDescription", "NSContactsUsageDescription"]:
            with self.subTest(key=key):
                self.info[key] = "request"
                with self.assertRaises(ValueError): self.verify()
                del self.info[key]
    def test_url_and_document_handlers_rejected(self):
        for key in ["CFBundleURLTypes", "CFBundleDocumentTypes", "NSServices", "NSExtension"]:
            with self.subTest(key=key):
                self.info[key] = []
                with self.assertRaises(ValueError): self.verify()
                del self.info[key]
    def test_extra_executable_rejected(self):
        (self.app / "Contents/MacOS/helper").write_bytes(b"payload")
        with self.assertRaises(ValueError): self.verify()
    def test_sensitive_imports_rejected(self):
        for symbol in ["_OBJC_CLASS_$_CLLocationManager", "_OBJC_CLASS_$_AVCaptureDevice", "_SecItemCopyMatching", "_dlopen", "_OBJC_CLASS_$_WKWebView"]:
            with self.subTest(symbol=symbol):
                self.symbols = symbol
                with self.assertRaises(ValueError): self.verify()
    def test_extra_entitlement_and_nonboolean_flag_rejected(self):
        for ent in [{"com.apple.security.app-sandbox": 1}, {"com.apple.security.app-sandbox": True, "com.apple.security.network.client": True}]:
            self.entitlements = ent
            with self.assertRaises(ValueError): self.verify()
    def test_missing_runtime_and_non_system_library_rejected(self):
        self.flags = "flags=0x2(adhoc)"
        with self.assertRaises(ValueError): self.verify()
        self.flags = "flags=0x10002(adhoc,runtime)"; self.libs = "binary:\n @rpath/foreign.dylib (compatibility version 1)\n"
        with self.assertRaises(ValueError): self.verify()

import json
from pathlib import Path
import sys
import tempfile
import unittest
sys.path.insert(0, str(Path(__file__).parents[2] / "scripts"))
from capability_policy import audit_runtime_sources, REQUIRED_POLICY

class SourceAuditTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(); self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        (self.root / "Sources").mkdir(); (self.root / "Security").mkdir()
        (self.root / "Security/CapabilityPolicy.json").write_text(json.dumps(REQUIRED_POLICY))
        self.source = self.root / "Sources/App.swift"
    def test_minimal_metadata_code_is_permitted(self):
        self.source.write_text("import AppKit\nlet app = NSWorkspace.shared.frontmostApplication")
        audit_runtime_sources(self.root)
    def test_broker_and_sensitive_api_routes_rejected(self):
        for code in ["NSWorkspace.shared.open(url)", "import CoreLocation", "let x = UserDefaults.standard", "dlopen(path, 1)"]:
            with self.subTest(code=code):
                self.source.write_text(code)
                with self.assertRaises(ValueError): audit_runtime_sources(self.root)
    def test_network_enabled_certificate_validation_rejected(self):
        self.source.write_text("SecCodeCheckValidity(code, kSecCSAllowNetworkAccess, requirement)")
        with self.assertRaises(ValueError): audit_runtime_sources(self.root)
    def test_code_validation_requires_explicit_offline_flag(self):
        self.source.write_text("SecCodeCheckValidity(code, SecCSFlags(rawValue: kSecCSStrictValidate), nil)")
        with self.assertRaises(ValueError): audit_runtime_sources(self.root)
        self.source.write_text("SecCodeCheckValidity(code, SecCSFlags(rawValue: kSecCSStrictValidate | SecCSFlags.noNetworkAccess.rawValue), nil)")
        audit_runtime_sources(self.root)
    def test_external_package_dependency_rejected(self):
        self.source.write_text("import AppKit")
        (self.root / "Package.swift").write_text('let dependency = .package(url: "https://example.invalid/sdk", from: "1.0.0")')
        with self.assertRaises(ValueError): audit_runtime_sources(self.root)

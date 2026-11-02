"""Opt-in real signed-artifact tests. They never execute the app."""
import os
from pathlib import Path
import plistlib
import shutil
import subprocess
import sys
import tempfile
import unittest
sys.path.insert(0, str(Path(__file__).parents[2] / "scripts"))
from verify_app import verify_app

@unittest.skipUnless(os.environ.get("PRIVACY_VERIFIED_APP"), "Set PRIVACY_VERIFIED_APP after building to test real signed bundles")
class SignedArtifactTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(); self.addCleanup(self.temp.cleanup)
        self.app = Path(self.temp.name) / "Fixture.app"
        shutil.copytree(os.environ["PRIVACY_VERIFIED_APP"], self.app)
    def sign(self, entitlements, runtime=True):
        path = Path(self.temp.name) / "entitlements.plist"
        path.write_bytes(plistlib.dumps(entitlements))
        subprocess.run(["codesign", "--force", "--sign", "-", "--timestamp=none", "--options",
                        "runtime" if runtime else "0", "--entitlements", str(path), str(self.app)],
                       check=True, capture_output=True)
    def test_real_clean_bundle_passes(self):
        verify_app(self.app)
    def test_real_extra_network_grant_is_rejected(self):
        self.sign({"com.apple.security.app-sandbox": True, "com.apple.security.network.client": True})
        with self.assertRaises(ValueError): verify_app(self.app)
    def test_real_missing_hardened_runtime_is_rejected(self):
        self.sign({"com.apple.security.app-sandbox": True}, runtime=False)
        with self.assertRaises(ValueError): verify_app(self.app)
    def test_real_modified_sealed_resource_is_rejected(self):
        resource = self.app / "Contents/Resources/source-manifest.json"
        resource.chmod(0o644); resource.write_text('{"tampered":true}')
        with self.assertRaises((ValueError, subprocess.CalledProcessError)): verify_app(self.app)

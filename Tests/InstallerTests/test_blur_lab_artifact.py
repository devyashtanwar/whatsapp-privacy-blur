"""Opt-in artifact checks for the synthetic-only lab. Never executes its GUI."""
import importlib.util
import os
from pathlib import Path
import plistlib
import shutil
import subprocess
import sys
import tempfile
import unittest

@unittest.skipUnless(os.environ.get('PRIVACY_BLUR_LAB_APP'), 'Build the separate blur lab and supply PRIVACY_BLUR_LAB_APP')
class BlurLabArtifactTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(); self.addCleanup(self.temp.cleanup)
        self.app = Path(self.temp.name) / 'Fixture.app'
        shutil.copytree(os.environ['PRIVACY_BLUR_LAB_APP'], self.app)
        path = Path(__file__).resolve().parents[2] / 'scripts/build-blur-lab.py'
        sys.path.insert(0, str(path.parent))
        spec = importlib.util.spec_from_file_location('blur_lab_builder', path)
        self.builder = importlib.util.module_from_spec(spec); spec.loader.exec_module(self.builder)

    def resign(self, extra=None, runtime=True):
        ent = {'com.apple.security.app-sandbox': True}; ent.update(extra or {})
        path = Path(self.temp.name) / 'entitlements.plist'; path.write_bytes(plistlib.dumps(ent))
        subprocess.run(['codesign', '--force', '--sign', '-', '--timestamp=none', '--options', 'runtime' if runtime else '0', '--entitlements', str(path), str(self.app)], check=True, capture_output=True)

    def test_clean_lab_passes(self):
        self.builder.verify_lab(self.app)

    def test_network_grant_rejected(self):
        self.resign({'com.apple.security.network.client': True})
        with self.assertRaises(ValueError): self.builder.verify_lab(self.app)

    def test_wrong_identity_rejected(self):
        path = self.app / 'Contents/Info.plist'; info = plistlib.loads(path.read_bytes())
        info['CFBundleIdentifier'] = 'other'; path.write_bytes(plistlib.dumps(info)); self.resign()
        with self.assertRaises(ValueError): self.builder.verify_lab(self.app)

    def test_missing_hardened_runtime_rejected(self):
        self.resign(runtime=False)
        with self.assertRaises(ValueError): self.builder.verify_lab(self.app)

    def test_sealed_manifest_tampering_rejected(self):
        path = self.app / 'Contents/Resources/lab-source-manifest.json'
        path.write_text('{"tampered":true}')
        with self.assertRaises((ValueError, subprocess.CalledProcessError)): self.builder.verify_lab(self.app)

"""Signed preview rejection tests. Never executes the application."""
import json
import os
from pathlib import Path
import plistlib
import shutil
import subprocess
import sys
import tempfile
import unittest
sys.path.insert(0, str(Path(__file__).resolve().parents[2] / 'scripts'))
from desktop_preview import verify_preview

@unittest.skipUnless(os.environ.get('PRIVACY_DESKTOP_PREVIEW_APP'), 'Build preview and supply PRIVACY_DESKTOP_PREVIEW_APP')
class DesktopPreviewArtifactTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(); self.addCleanup(self.temp.cleanup)
        self.app = Path(self.temp.name) / 'Preview.app'
        shutil.copytree(os.environ['PRIVACY_DESKTOP_PREVIEW_APP'], self.app)

    def resign(self, extra=None, runtime=True):
        grants = {'com.apple.security.app-sandbox': True}; grants.update(extra or {})
        ent = Path(self.temp.name) / 'grants.plist'; ent.write_bytes(plistlib.dumps(grants))
        subprocess.run(['codesign', '--force', '--sign', '-', '--options', 'runtime' if runtime else '0',
                        '--timestamp=none', '--entitlements', str(ent), str(self.app)], check=True, capture_output=True)

    def test_valid_preview(self):
        verify_preview(self.app)

    def test_extra_grants_rejected(self):
        for key in ['com.apple.security.network.client', 'com.apple.security.device.audio-input',
                    'com.apple.security.accessibility', 'com.apple.security.files.user-selected.read-only']:
            with self.subTest(grant=key):
                self.resign({key: True})
                with self.assertRaises(ValueError): verify_preview(self.app)

    def test_wrong_bundle_or_lab_identity(self):
        path = self.app / 'Contents/Info.plist'; info = plistlib.loads(path.read_bytes())
        for identity in ['devyashtanwar.whatsapp-privacy-cover', 'devyashtanwar.selective-blur-lab']:
            info['CFBundleIdentifier'] = identity; path.write_bytes(plistlib.dumps(info)); self.resign()
            with self.subTest(identity=identity), self.assertRaises(ValueError): verify_preview(self.app)

    def test_runtime_required(self):
        self.resign(runtime=False)
        with self.assertRaises(ValueError): verify_preview(self.app)

    def test_resigned_scope_widening_rejected(self):
        path = self.app / 'Contents/Resources/capability-policy.json'
        policy = json.loads(path.read_text()); policy['captureScope'] = 'display'; path.write_text(json.dumps(policy)); self.resign()
        with self.assertRaises(ValueError): verify_preview(self.app)

    def test_sealed_resources_required(self):
        path = self.app / 'Contents/Resources/source-manifest.json'
        data = json.loads(path.read_text()); data['baseRevision'] = 'tampered'; path.write_text(json.dumps(data))
        with self.assertRaises((ValueError, subprocess.CalledProcessError)): verify_preview(self.app)

    def test_resigned_extra_helper_rejected(self):
        (self.app / 'Contents/Resources/helper.txt').write_text('not allowed'); self.resign()
        with self.assertRaises(ValueError): verify_preview(self.app)

    def test_symbolic_bundle_rejected(self):
        link = Path(self.temp.name) / 'Alias.app'; link.symlink_to(self.app, target_is_directory=True)
        with self.assertRaises(ValueError): verify_preview(link)

    def test_resigned_bootstrap_provenance_change_rejected(self):
        path = self.app / 'Contents/Resources/source-manifest.json'
        manifest = json.loads(path.read_text())
        for entry in manifest['inputs']:
            if entry['compiledPath'] == 'Sources/DesktopBlurPreview/main.swift':
                entry['sha256'] = '0' * 64
        path.write_text(json.dumps(manifest)); self.resign()
        with self.assertRaises(ValueError): verify_preview(self.app)

    def test_binary_without_self_validation_rejected(self):
        # Replace but never execute: signature flags alone cannot establish a startup gate.
        shutil.copyfile('/usr/bin/true', self.app / 'Contents/MacOS/DesktopBlurPreview')
        self.resign()
        with self.assertRaises(ValueError): verify_preview(self.app)

    def test_resigned_network_linkage_rejected(self):
        # Alter only this disposable fixture's load command; never execute it.
        binary = self.app / 'Contents/MacOS/DesktopBlurPreview'
        libraries = subprocess.check_output(['otool', '-L', str(binary)], text=True)
        appkit = next(line.strip().split(' ')[0] for line in libraries.splitlines()[1:] if '/AppKit.framework/' in line)
        vision = '/System/Library/Frameworks/Network.framework/Versions/A/Network'
        subprocess.run(['install_name_tool', '-change', appkit, vision, str(binary)], check=True, capture_output=True)
        self.resign()
        with self.assertRaisesRegex(ValueError, 'Forbidden network framework'):
            verify_preview(self.app)

"""Real code-requirement tests; fixtures are inspected, never launched."""
import os
from pathlib import Path
import plistlib
import shutil
import subprocess
import tempfile
import unittest

@unittest.skipUnless(os.environ.get('TARGET_IDENTITY_HARNESS'), 'Run scripts/test.sh to build the Security API harness')
class TargetIdentityTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(); self.addCleanup(self.temp.cleanup)
        self.app = Path(self.temp.name) / 'Impostor.app'
        contents = self.app / 'Contents'
        (contents / 'MacOS').mkdir(parents=True)
        self.binary = contents / 'MacOS/Impostor'
        shutil.copyfile('/bin/echo', self.binary)
        self.binary.chmod(0o755)
        subprocess.run(['/usr/bin/codesign', '--remove-signature', str(self.binary)], check=True, capture_output=True)
        (contents / 'Info.plist').write_bytes(plistlib.dumps({'CFBundleIdentifier': 'net.whatsapp.WhatsApp', 'CFBundleExecutable': 'Impostor'}))

    def check(self, path, outcome='reject', kind='--fixture'):
        result = subprocess.run([os.environ['TARGET_IDENTITY_HARNESS'], kind, str(path), outcome], capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def sign(self, team='57T9237FN3', application='UKFA9XBX6K.net.whatsapp.WhatsApp'):
        entitlements = Path(self.temp.name) / 'entitlements.plist'
        entitlements.write_bytes(plistlib.dumps({'com.apple.developer.team-identifier': team, 'com.apple.application-identifier': application}))
        subprocess.run(['/usr/bin/codesign', '--force', '--sign', '-', '--timestamp=none', '--identifier', 'net.whatsapp.WhatsApp', '--entitlements', str(entitlements), str(self.app)], check=True, capture_output=True)

    def test_unsigned_same_identifier_rejected(self):
        self.check(self.app)

    def test_adhoc_with_copied_signed_identifiers_rejected(self):
        self.sign(); self.check(self.app)

    def test_wrong_team_or_application_rejected(self):
        for team, app in [('OTHERTEAM', 'UKFA9XBX6K.net.whatsapp.WhatsApp'), ('57T9237FN3', 'OTHER.net.whatsapp.WhatsApp')]:
            self.sign(team, app); self.check(self.app)

    def test_tampered_code_rejected(self):
        self.sign()
        with self.binary.open('ab') as binary: binary.write(b'tampered')
        self.check(self.app)

    def test_unrelated_apple_signed_code_rejected(self):
        self.check('/bin/echo')

    @unittest.skipUnless(os.environ.get('TARGET_APP_STORE_FIXTURE'), 'Authentic App Store fixture not supplied')
    def test_authentic_app_store_fixture(self):
        self.check(os.environ['TARGET_APP_STORE_FIXTURE'], 'accept', '--store-fixture')
        self.check(os.environ['TARGET_APP_STORE_FIXTURE'], 'accept')
        self.check(os.environ['TARGET_APP_STORE_FIXTURE'], 'reject', '--developer-id-fixture')

    @unittest.skipUnless(os.environ.get('TARGET_DEVELOPER_ID_FIXTURE'), 'Authentic Developer ID fixture not supplied')
    def test_authentic_developer_id_fixture(self):
        self.check(os.environ['TARGET_DEVELOPER_ID_FIXTURE'], 'accept', '--developer-id-fixture')
        self.check(os.environ['TARGET_DEVELOPER_ID_FIXTURE'], 'accept')
        self.check(os.environ['TARGET_DEVELOPER_ID_FIXTURE'], 'reject', '--store-fixture')

    @unittest.skipUnless(os.environ.get('TARGET_IDENTITY_PID'), 'Live process sandbox test requires explicit TARGET_IDENTITY_PID')
    def test_sandbox_only_offline_running_process(self):
        bundle = Path(self.temp.name) / 'IdentityHarness.app'
        contents = bundle / 'Contents'; (contents / 'MacOS').mkdir(parents=True)
        binary = contents / 'MacOS/TargetIdentityTests'
        shutil.copyfile(os.environ['TARGET_IDENTITY_HARNESS'], binary); binary.chmod(0o755)
        (contents / 'Info.plist').write_bytes(plistlib.dumps({'CFBundleIdentifier': 'devyashtanwar.identity-test', 'CFBundleExecutable': 'TargetIdentityTests', 'CFBundlePackageType': 'APPL'}))
        entitlements = Path(self.temp.name) / 'sandbox.plist'
        entitlements.write_bytes(plistlib.dumps({'com.apple.security.app-sandbox': True}))
        subprocess.run(['/usr/bin/codesign', '--force', '--sign', '-', '--options', 'runtime', '--timestamp=none', '--entitlements', str(entitlements), str(bundle)], check=True, capture_output=True)
        result = subprocess.run([str(binary), '--pid', os.environ['TARGET_IDENTITY_PID']], capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

"""Exercise the real shell entry point without building or installing an app."""
import json
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]

class InstallShellTests(unittest.TestCase):
    def invoke(self, *args):
        with tempfile.TemporaryDirectory(prefix='privacy install ') as directory:
            root = Path(directory)
            shutil.copy2(ROOT / 'install.sh', root / 'install.sh')
            (root / 'scripts').mkdir()
            (root / 'build-app.sh').write_text('#!/bin/bash\nexit 0\n')
            (root / 'build-app.sh').chmod(0o755)
            (root / 'scripts/verify_app.py').write_text('pass\n')
            (root / 'scripts/install_bundle.py').write_text('import json,sys\nprint(json.dumps(sys.argv[1:]))\n')
            result = subprocess.run(['/bin/bash', str(root / 'install.sh'), *args], capture_output=True, text=True)
            return result, root

    def check_install(self, replace):
        result, root = self.invoke(*(['--replace'] if replace else []))
        self.assertEqual(result.returncode, 0, result.stderr)
        expected = ['--source', str(root / 'dist/WhatsApp Privacy Cover.app'), '--destination', str(Path.home() / 'Applications/WhatsApp Privacy Cover.app')]
        if replace:
            expected.append('--replace')
        self.assertEqual(json.loads(result.stdout), expected)

    def test_fresh_install_on_system_bash(self):
        self.check_install(False)

    def test_replacement_on_system_bash(self):
        self.check_install(True)

    def test_invalid_arguments_are_rejected(self):
        for args in [('--unknown',), ('--replace', 'extra')]:
            result, _ = self.invoke(*args)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn('Usage:', result.stderr)
            self.assertEqual(result.stdout, '')

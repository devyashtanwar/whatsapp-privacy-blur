import hashlib
from pathlib import Path
import sys
import tempfile
import unittest
sys.path.insert(0, str(Path(__file__).parents[2] / "scripts"))
from source_snapshot import prepare_source_snapshot

class SnapshotTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(); self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name).resolve()
        for name in ["Sources/App", "scripts", "Security", "Tests/PrivacyCoreTests"]:
            (self.root / name).mkdir(parents=True)
        for name in ["Package.swift", "Info.plist", "PrivacyCover.entitlements", "build-app.sh"]:
            (self.root / name).write_text("fixture")
        self.source = self.root / "Sources/App/main.swift"; self.source.write_text("original")
    def test_snapshot_stays_bound_to_original_compiler_bytes(self):
        with prepare_source_snapshot(self.root, self.root / ".build") as snapshot:
            compiler_bytes = (snapshot.root / "Sources/App/main.swift").read_bytes()
            self.source.write_text("edited-after-compilation")
            self.assertEqual((snapshot.root / "Sources/App/main.swift").read_bytes(), compiler_bytes)
            item = next(x for x in snapshot.manifest["inputs"] if x["path"] == "Sources/App/main.swift")
            self.assertEqual(item["sha256"], hashlib.sha256(compiler_bytes).hexdigest())
        self.assertEqual(self.source.read_text(), "edited-after-compilation")
    def test_source_symlink_is_rejected(self):
        (self.root / "Sources/App/linked.swift").symlink_to(self.source)
        with self.assertRaises(ValueError):
            with prepare_source_snapshot(self.root, self.root / ".build"): pass
    def test_missing_required_input_is_rejected(self):
        (self.root / "Package.swift").unlink()
        with self.assertRaises((ValueError, FileNotFoundError)):
            with prepare_source_snapshot(self.root, self.root / ".build"): pass
    def test_redirected_workspace_is_rejected(self):
        outside = self.root / "outside"; outside.mkdir()
        (self.root / ".build").symlink_to(outside, target_is_directory=True)
        with self.assertRaises(ValueError):
            with prepare_source_snapshot(self.root, self.root / ".build"): pass

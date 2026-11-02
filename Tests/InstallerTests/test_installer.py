import importlib.util
from functools import partial
import os
from pathlib import Path
import shutil
import tempfile
import unittest
import sys
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).parents[2] / "scripts"))
spec = importlib.util.spec_from_file_location("installer", Path(__file__).parents[2] / "scripts" / "install_bundle.py")
installer = importlib.util.module_from_spec(spec)
spec.loader.exec_module(installer)


class InstallerTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name).resolve()
        self.source = self.root / "built.app"
        self.source.mkdir()
        (self.source / "payload").write_text("new")
        self.destination = self.root / "Applications" / "Cover.app"
        # Fixture bundles contain text instead of Mach-O code. Signature validation
        # is a platform boundary; failure handling is tested with reject_staged.
        self.install = partial(installer.install_bundle, validator=lambda staged: None)

    def existing(self):
        self.destination.mkdir(parents=True)
        (self.destination / "payload").write_text("old")

    def test_fresh_install_copies_without_changing_source(self):
        backup = self.install(self.source, self.destination)
        self.assertIsNone(backup)
        self.assertEqual((self.destination / "payload").read_text(), "new")
        self.assertEqual((self.source / "payload").read_text(), "new")

    def test_existing_install_requires_explicit_replace(self):
        self.existing()
        with self.assertRaises(FileExistsError):
            self.install(self.source, self.destination)
        self.assertEqual((self.destination / "payload").read_text(), "old")

    def test_replacement_retains_recoverable_backup(self):
        self.existing()
        backup = self.install(self.source, self.destination, replace=True)
        self.assertEqual((self.destination / "payload").read_text(), "new")
        self.assertEqual((backup / "payload").read_text(), "old")

    def test_copy_failure_preserves_existing_install(self):
        self.existing()
        with patch.object(installer.shutil, "copytree", side_effect=OSError("copy failure")):
            with self.assertRaises(OSError):
                self.install(self.source, self.destination, replace=True)
        self.assertEqual((self.destination / "payload").read_text(), "old")

    def test_commit_failure_rolls_back_existing_install(self):
        self.existing()
        real_replace = installer.atomic_publish_no_replace
        def fail_new_install(source, destination):
            if Path(destination) == self.destination and Path(source).name == "staged.app":
                raise OSError("rename failure")
            return real_replace(source, destination)
        with patch.object(installer, "atomic_publish_no_replace", side_effect=fail_new_install):
            with self.assertRaises(OSError):
                self.install(self.source, self.destination, replace=True)
        self.assertEqual((self.destination / "payload").read_text(), "old")

    def test_symlink_destination_is_refused(self):
        self.destination.parent.mkdir()
        self.destination.symlink_to(self.source, target_is_directory=True)
        with self.assertRaises(ValueError):
            self.install(self.source, self.destination, replace=True)
        self.assertEqual((self.source / "payload").read_text(), "new")

    def test_missing_source_preserves_existing(self):
        self.existing()
        shutil.rmtree(self.source)
        with self.assertRaises(ValueError):
            self.install(self.source, self.destination, replace=True)
        self.assertEqual((self.destination / "payload").read_text(), "old")

    def test_source_symlinks_are_refused(self):
        (self.source / "linked").symlink_to(self.root / "private")
        with self.assertRaises(ValueError):
            self.install(self.source, self.destination)

    def test_staged_validation_failure_preserves_existing_install(self):
        self.existing()
        def reject_staged(staged):
            self.assertNotEqual(staged, self.source)
            self.assertEqual((staged / "payload").read_text(), "new")
            self.assertEqual((self.destination / "payload").read_text(), "old")
            raise ValueError("invalid staged signature")
        with self.assertRaises(ValueError):
            installer.install_bundle(self.source, self.destination, replace=True, validator=reject_staged)
        self.assertEqual((self.destination / "payload").read_text(), "old")


if __name__ == "__main__":
    unittest.main()

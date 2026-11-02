import sys
import tempfile
import unittest
import unicodedata
from pathlib import Path
from unittest.mock import patch
sys.path.insert(0, str(Path(__file__).parents[2] / "scripts"))
from install_bundle import install_bundle

class PathAndRaceTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(); self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name).resolve()
        self.source = self.root / "Source.app"; self.source.mkdir()
        (self.source / "payload").write_text("candidate")
        self.destination = self.root / "Applications/Cover.app"
    def test_destination_created_during_validation_is_not_replaced(self):
        def competing(staged):
            self.destination.mkdir()
            (self.destination / "payload").write_text("competitor")
        with self.assertRaises(FileExistsError):
            install_bundle(self.source, self.destination, validator=competing)
        self.assertEqual((self.destination / "payload").read_text(), "competitor")
    def test_parent_alias_into_source_rejected_before_copy(self):
        alias = self.root / "alias"; alias.symlink_to(self.source, target_is_directory=True)
        with patch("install_bundle.shutil.copytree", side_effect=AssertionError("unsafe staging inside source")):
            with self.assertRaises(ValueError):
                install_bundle(self.source, alias / "nested.app", replace=True, validator=lambda path: None)
    def test_same_source_through_alias_is_rejected(self):
        alias = self.root / "alias"; alias.symlink_to(self.root, target_is_directory=True)
        with patch("install_bundle.shutil.copytree", side_effect=AssertionError("unsafe same source")):
            with self.assertRaises(ValueError):
                install_bundle(self.source, alias / "Source.app", replace=True, validator=lambda path: None)
    def test_legitimate_separate_parent_alias_works(self):
        real = self.root / "real"; real.mkdir()
        alias = self.root / "alias"; alias.symlink_to(real, target_is_directory=True)
        install_bundle(self.source, alias / "Cover.app", validator=lambda path: None)
        self.assertEqual((real / "Cover.app/payload").read_text(), "candidate")
    def test_case_alias_of_source_is_rejected_before_copy(self):
        alias = self.root / "source.app"
        if not alias.exists() or not alias.samefile(self.source):
            self.skipTest("Requires a case-insensitive filesystem")
        with patch("install_bundle.shutil.copytree", side_effect=AssertionError("unsafe same inode")):
            with self.assertRaises(ValueError):
                install_bundle(self.source, alias, replace=True, validator=lambda path: None)
    def test_descendant_through_case_alias_is_rejected_before_copy(self):
        alias = self.root / "source.app"
        if not alias.exists() or not alias.samefile(self.source):
            self.skipTest("Requires a case-insensitive filesystem")
        with patch("install_bundle.shutil.copytree", side_effect=AssertionError("unsafe inode ancestor")):
            with self.assertRaises(ValueError):
                install_bundle(self.source, alias / "nested.app", replace=True, validator=lambda path: None)
    def test_unicode_normalization_alias_is_rejected_before_copy(self):
        source = self.root / "Café.app"; source.mkdir()
        alias = self.root / unicodedata.normalize("NFD", source.name)
        if not alias.exists() or not alias.samefile(source):
            self.skipTest("Requires a normalization-insensitive filesystem")
        with patch("install_bundle.shutil.copytree", side_effect=AssertionError("unsafe normalized alias")):
            with self.assertRaises(ValueError):
                install_bundle(source, alias / "nested.app", replace=True, validator=lambda path: None)

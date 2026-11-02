import os
import select
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch
sys.path.insert(0, str(Path(__file__).parents[2] / "scripts"))
from atomic_publish import atomic_publish_no_replace, destination_lock
from install_bundle import install_bundle, InstallRecoveryError, build_output_destination

class AtomicPublicationTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(); self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name).resolve()
    def test_kernel_rename_does_not_replace_existing_empty_directory(self):
        source = self.root / "source"; source.mkdir(); (source / "data").write_text("new")
        dest = self.root / "dest"; dest.mkdir()
        with self.assertRaises(FileExistsError): atomic_publish_no_replace(source, dest)
        self.assertTrue(source.exists()); self.assertTrue(dest.is_dir()); self.assertFalse((dest / "data").exists())
    def test_alias_names_share_one_physical_directory_lock(self):
        scripts = str(Path(__file__).parents[2] / "scripts")
        program = """import sys
from pathlib import Path
sys.path.insert(0,sys.argv[1])
from atomic_publish import destination_lock
print('ready',flush=True)
with destination_lock(Path(sys.argv[2])):
    print('acquired',flush=True)
"""
        child = None
        try:
            with destination_lock(self.root / "Cover.app"):
                child = subprocess.Popen([sys.executable, "-c", program, scripts, str(self.root / "cover.app")],
                    stdout=subprocess.PIPE, stderr=subprocess.PIPE, bufsize=0)
                self.assertEqual(child.stdout.readline(), b"ready\n")
                readable, _, _ = select.select([child.stdout], [], [], 0.15)
                self.assertFalse(readable, "Alias transaction acquired the directory lock concurrently")
            out, err = child.communicate(timeout=15)
            self.assertEqual(child.returncode, 0, err)
            self.assertIn(b"acquired", out)
        finally:
            if child is not None and child.poll() is None:
                child.kill(); child.communicate()
    def test_symlinked_build_output_never_mutates_external_app(self):
        outside = self.root / "Applications"; outside.mkdir()
        app = outside / "WhatsApp Privacy Cover.app"; app.mkdir(); (app / "old").write_text("keep")
        repo = self.root / "repo"; repo.mkdir(); (repo / "dist").symlink_to(outside, target_is_directory=True)
        with self.assertRaises(ValueError): build_output_destination(repo)
        self.assertEqual((app / "old").read_text(), "keep")
    def test_rollback_conflict_preserves_backup_and_new_destination(self):
        source = self.root / "source.app"; source.mkdir(); (source / "data").write_text("new")
        dest = self.root / "dest.app"; dest.mkdir(); (dest / "data").write_text("old")
        real = atomic_publish_no_replace
        def conflict(src, dst):
            if Path(src).name == "staged.app":
                dest.mkdir(); (dest / "data").write_text("competitor")
                raise OSError("publish interrupted")
            return real(src, dst)
        with patch("install_bundle.atomic_publish_no_replace", side_effect=conflict):
            with self.assertRaises(InstallRecoveryError) as error:
                install_bundle(source, dest, replace=True, validator=lambda staged: None)
        self.assertEqual((error.exception.backup / "data").read_text(), "old")
        self.assertEqual((dest / "data").read_text(), "competitor")
    def test_two_processes_exactly_one_installs(self):
        repo_scripts = str(Path(__file__).parents[2] / "scripts")
        sources = []
        for name in ["a.app", "b.app"]:
            path = self.root / name; path.mkdir(); (path / "data").write_text(name); sources.append(path)
        dest = self.root / "dest.app"
        program = """import sys,time
sys.path.insert(0,sys.argv[1])
from install_bundle import install_bundle
try:
    install_bundle(sys.argv[2],sys.argv[3],validator=lambda staged:time.sleep(0.1))
    print('installed')
except FileExistsError:
    print('refused')
"""
        children = [subprocess.Popen([sys.executable, "-c", program, repo_scripts, str(src), str(dest)], stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True) for src in sources]
        try:
            completed = [(child, *child.communicate(timeout=15)) for child in children]
        finally:
            for child in children:
                if child.poll() is None:
                    child.kill(); child.communicate()
        for child, out, err in completed:
            self.assertEqual(child.returncode, 0, err)
        self.assertEqual(sorted(out.strip() for child, out, err in completed), ["installed", "refused"])

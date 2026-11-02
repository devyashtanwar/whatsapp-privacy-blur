"""Compile fixed private input bytes, never a mutable live checkout."""
from contextlib import contextmanager
from dataclasses import dataclass
import hashlib
import os
from pathlib import Path
import stat
import subprocess
import tempfile

INPUTS = ["Sources", "scripts", "Security", "Tests", "Package.swift", "Info.plist",
          "PrivacyCover.entitlements", "build-app.sh"]

@dataclass
class SourceSnapshot:
    root: Path
    manifest: dict

def revision(repo):
    result = subprocess.run(["git", "-C", str(repo), "rev-parse", "HEAD"],
                            capture_output=True, text=True)
    return result.stdout.strip() if result.returncode == 0 else None

def stable_bytes(path):
    before = path.lstat()
    if not stat.S_ISREG(before.st_mode):
        raise ValueError("Build input must be a regular file: " + str(path))
    descriptor = os.open(path, os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK)
    with os.fdopen(descriptor, "rb") as file:
        first = os.fstat(file.fileno())
        content = file.read()
        last = os.fstat(file.fileno())
    def identity(value):
        return (value.st_dev, value.st_ino, value.st_size, value.st_mtime_ns, value.st_ctime_ns)
    if identity(before) != identity(first) or identity(first) != identity(last):
        raise ValueError("Input changed while snapshotting: " + str(path))
    return content, first.st_mode

@contextmanager
def prepare_source_snapshot(repo, workspace):
    repo, workspace = Path(repo).resolve(strict=True), Path(workspace).absolute()
    if workspace.is_symlink():
        raise ValueError("Snapshot workspace must not be redirected")
    workspace.mkdir(parents=True, exist_ok=True)
    start_revision = revision(repo)
    with tempfile.TemporaryDirectory(prefix="source-snapshot-", dir=workspace) as temporary:
        root = Path(temporary) / "inputs"; root.mkdir()
        manifest = {"schemaVersion": 1, "baseRevision": start_revision, "inputs": []}
        for name in INPUTS:
            source = repo / name
            if source.is_symlink() or not source.exists():
                raise ValueError("Missing or symbolic build input: " + name)
            if source.is_dir():
                (root / name).mkdir(parents=True, exist_ok=True)
                candidates = sorted(source.rglob("*"))
            else: candidates = [source]
            for item in candidates:
                if "__pycache__" in item.parts or item.suffix == ".pyc": continue
                if item.is_symlink():
                    raise ValueError("Symbolic build input: " + str(item))
                relative = item.relative_to(repo)
                if item.is_dir():
                    (root / relative).mkdir(parents=True, exist_ok=True)
                    continue
                content, mode = stable_bytes(item)
                target = root / relative; target.parent.mkdir(parents=True, exist_ok=True)
                target.write_bytes(content)
                target.chmod(0o555 if mode & 0o111 else 0o444)
                manifest["inputs"].append({"path": relative.as_posix(),
                    "sha256": hashlib.sha256(content).hexdigest()})
        if revision(repo) != start_revision:
            raise ValueError("Checkout revision changed during snapshot preparation")
        status = subprocess.run(["git", "-C", str(repo), "status", "--porcelain"],
                                capture_output=True, text=True)
        manifest["dirtyCheckout"] = bool(status.stdout.strip()) if status.returncode == 0 else None
        manifest["inputs"].sort(key=lambda entry: entry["path"])
        yield SourceSnapshot(root=root, manifest=manifest)

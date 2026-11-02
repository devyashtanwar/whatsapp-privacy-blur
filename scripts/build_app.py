#!/usr/bin/env python3
"""Build/sign/verify a local artifact. Never install or launch it."""
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import tempfile
import os

from install_bundle import install_bundle
from verify_app import verify_app

ROOT = Path(__file__).resolve().parents[1]
APP_NAME = "WhatsApp Privacy Cover.app"


def main():
    wrapper = ROOT / "scripts" / "swift.sh"
    subprocess.run([str(wrapper), "build", "-c", "release", "--product", "HideWhatsApp"], check=True)
    binary_dir = subprocess.check_output([str(wrapper), "build", "-c", "release", "--show-bin-path"], text=True).strip()
    with tempfile.TemporaryDirectory(prefix="bundle-", dir=ROOT / ".build") as temporary:
        app = Path(temporary) / APP_NAME
        executable = app / "Contents" / "MacOS" / "HideWhatsApp"
        resources = app / "Contents" / "Resources"
        executable.parent.mkdir(parents=True)
        resources.mkdir()
        shutil.copy2(Path(binary_dir) / "HideWhatsApp", executable)
        shutil.copy2(ROOT / "Info.plist", app / "Contents" / "Info.plist")
        # Record exact inputs, including uncommitted files; do not claim reproducibility.
        inputs = []
        for name in ["Sources", "scripts", "Package.swift", "Info.plist", "PrivacyCover.entitlements"]:
            path = ROOT / name
            candidates = sorted(path.rglob("*")) if path.is_dir() else [path]
            for item in candidates:
                if item.is_file() and "__pycache__" not in item.parts:
                    inputs.append({"path": str(item.relative_to(ROOT)), "sha256": hashlib.sha256(item.read_bytes()).hexdigest()})
        revision = subprocess.check_output(["git", "-C", str(ROOT), "rev-parse", "HEAD"], text=True).strip()
        (resources / "source-manifest.json").write_text(json.dumps({"baseRevision": revision, "inputs": inputs}, indent=2) + "\n")
        identity = os.environ.get("SIGNING_IDENTITY", "-")
        timestamp = "--timestamp=none" if identity == "-" else "--timestamp"
        subprocess.run(["codesign", "--force", "--sign", identity, "--options", "runtime", timestamp,
                        "--entitlements", str(ROOT / "PrivacyCover.entitlements"), str(app)], check=True)
        verify_app(app)
        destination = ROOT / "dist" / APP_NAME
        backup = install_bundle(app, destination, replace=True)
        # Only an earlier generated build is removed; installed applications are untouched.
        if backup is not None:
            shutil.rmtree(backup)
    binary = destination / "Contents" / "MacOS" / "HideWhatsApp"
    digest = hashlib.sha256(binary.read_bytes()).hexdigest()
    (ROOT / "dist" / "HideWhatsApp.sha256").write_text(digest + "  HideWhatsApp\n")
    print("Verified build artifact:", destination)
    print("Executable SHA-256:", digest)
    print("Local ad-hoc signing is not Developer ID notarization." if identity == "-" else "Developer ID signing does not itself establish notarization.")


if __name__ == "__main__":
    main()

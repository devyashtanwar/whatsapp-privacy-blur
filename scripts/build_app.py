#!/usr/bin/env python3
"""Build a fixed source snapshot; sign and verify without installing or launching."""
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import tempfile
import os
from atomic_publish import destination_lock
from install_bundle import install_bundle, build_output_destination
from source_snapshot import prepare_source_snapshot
from verify_app import verify_app
from capability_policy import audit_runtime_sources

ROOT = Path(__file__).resolve().parents[1]
APP_NAME = "WhatsApp Privacy Cover.app"

def main():
    destination = build_output_destination(ROOT)
    workspace = ROOT / ".build"
    if workspace.is_symlink():
        raise ValueError("Build workspace must not be redirected")
    workspace.mkdir(exist_ok=True)
    # Serialize build publication and sidecar updates separately from installer locks.
    with destination_lock(destination.parent / ".build-operation", scope="build") as unchanged:
        with prepare_source_snapshot(ROOT, workspace) as snapshot:
            audit_runtime_sources(snapshot.root)
            wrapper = snapshot.root / "scripts/swift.sh"
            subprocess.run([str(wrapper), "build", "-c", "release", "--product", "HideWhatsApp"], check=True)
            binary_dir = subprocess.check_output([str(wrapper), "build", "-c", "release", "--show-bin-path"], text=True).strip()
            with tempfile.TemporaryDirectory(prefix="bundle-", dir=workspace) as temporary:
                app = Path(temporary) / APP_NAME
                executable = app / "Contents/MacOS/HideWhatsApp"
                resources = app / "Contents/Resources"
                executable.parent.mkdir(parents=True); resources.mkdir()
                shutil.copy2(Path(binary_dir) / "HideWhatsApp", executable)
                shutil.copy2(snapshot.root / "Info.plist", app / "Contents/Info.plist")
                shutil.copy2(snapshot.root / "Security/CapabilityPolicy.json", resources / "capability-policy.json")
                (resources / "source-manifest.json").write_text(json.dumps(snapshot.manifest, indent=2) + "\n")
                identity = os.environ.get("SIGNING_IDENTITY", "-")
                timestamp = "--timestamp=none" if identity == "-" else "--timestamp"
                subprocess.run(["codesign", "--force", "--sign", identity, "--options", "runtime", timestamp,
                    "--entitlements", str(snapshot.root / "PrivacyCover.entitlements"), str(app)], check=True)
                verify_app(app)
                digest = hashlib.sha256(executable.read_bytes()).hexdigest()
                unchanged()
                backup = install_bundle(app, destination, replace=True)
                unchanged()
                if backup is not None:
                    # Confined to the verified managed dist directory. Never clean installed backups.
                    if backup.parent != destination.parent or backup.is_symlink():
                        raise ValueError("Unsafe generated backup location")
                    shutil.rmtree(backup)
            unchanged()
            with tempfile.NamedTemporaryFile(mode="w", dir=destination.parent, delete=False) as sidecar:
                sidecar.write(digest + "  HideWhatsApp\n")
                sidecar_path = Path(sidecar.name)
            try:
                unchanged()
                os.replace(sidecar_path, destination.parent / "HideWhatsApp.sha256")
            finally:
                sidecar_path.unlink(missing_ok=True)
    print("Verified snapshot build:", destination)
    print("Executable SHA-256:", digest)
    print("Local ad-hoc signing is not notarization." if identity == "-" else "Developer ID signing does not itself establish notarization.")

if __name__ == "__main__":
    main()

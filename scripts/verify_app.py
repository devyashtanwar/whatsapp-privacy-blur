#!/usr/bin/env python3
"""Inspect a signed artifact without executing it."""
from pathlib import Path
import json
import plistlib
import re
import subprocess
import sys
from capability_policy import RESOURCES, SENSITIVE_SYMBOLS, validate_metadata, validate_policy

def verify_app(app):
    app = Path(app)
    if app.is_symlink() or not app.is_dir() or any(p.is_symlink() for p in app.rglob("*")):
        raise ValueError("App must be a real bundle without symlinks")
    executable = app / "Contents/MacOS/HideWhatsApp"
    allowed = {"Contents/Info.plist", "Contents/MacOS/HideWhatsApp", "Contents/_CodeSignature/CodeResources"}
    allowed.update("Contents/Resources/" + name for name in RESOURCES)
    for path in app.rglob("*"):
        if path.is_file() and str(path.relative_to(app)) not in allowed:
            raise ValueError("Unexpected shipped resource/executable: " + str(path.relative_to(app)))
    validate_policy(json.loads((app / "Contents/Resources/capability-policy.json").read_text()))
    info = plistlib.loads((app / "Contents/Info.plist").read_bytes())
    subprocess.run(["codesign", "--verify", "--strict", "--all-architectures", str(app)], check=True)
    ent = subprocess.run(["codesign", "-d", "--entitlements", "-", "--xml", str(app)], check=True, capture_output=True)
    validate_metadata(info, plistlib.loads(ent.stdout))
    signature = subprocess.run(["codesign", "-d", "--verbose=4", str(app)], check=True, capture_output=True, text=True)
    flags = re.search(r"flags=(0x[0-9a-fA-F]+)", signature.stderr)
    if flags is None or not int(flags.group(1), 16) & 0x10000:
        raise ValueError("Hardened runtime is missing")
    symbols = subprocess.check_output(["nm", "-u", str(executable)], text=True)
    for pattern in SENSITIVE_SYMBOLS:
        if re.search(pattern, symbols):
            raise ValueError("Unexpected sensitive API import: " + pattern)
    libraries = subprocess.check_output(["otool", "-L", str(executable)], text=True)
    for line in libraries.splitlines()[1:]:
        library = line.strip().split(" (", 1)[0]
        if not library.startswith(("/System/Library/", "/usr/lib/")):
            raise ValueError("Unexpected non-system dynamic library: " + library)
    print("Verified signature, sandbox-only capabilities, runtime hardening, bundle layout and linked APIs.")

if __name__ == "__main__":
    try:
        verify_app(sys.argv[1])
    except (ValueError, OSError, subprocess.CalledProcessError) as error:
        sys.exit(str(error))

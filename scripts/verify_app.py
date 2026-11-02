#!/usr/bin/env python3
"""Static checks on the signed app; does not execute its binary."""
from pathlib import Path
import plistlib
import re
import subprocess
import sys


def verify_app(app):
    app = Path(app)
    executable = app / "Contents" / "MacOS" / "HideWhatsApp"
    if any(path.is_symlink() for path in app.rglob("*")):
        raise ValueError("Unexpected symbolic link in app")
    with (app / "Contents" / "Info.plist").open("rb") as file:
        info = plistlib.load(file)
    if info.get("CFBundleIdentifier") != "devyashtanwar.whatsapp-privacy-cover" or info.get("CFBundleExecutable") != "HideWhatsApp":
        raise ValueError("Unexpected app identity")
    subprocess.run(["codesign", "--verify", "--strict", str(app)], check=True)
    result = subprocess.run(["codesign", "-d", "--entitlements", "-", "--xml", str(app)], check=True, capture_output=True)
    entitlements = plistlib.loads(result.stdout)
    if entitlements != {"com.apple.security.app-sandbox": True}:
        raise ValueError("App must have only its sandbox entitlement (no network, files, or device grants)")
    signature = subprocess.run(["codesign", "-d", "--verbose=4", str(app)], check=True, capture_output=True, text=True)
    flags = re.search(r"flags=(0x[0-9a-fA-F]+)", signature.stderr)
    if flags is None or not int(flags.group(1), 16) & 0x10000:
        raise ValueError("Hardened runtime is missing")
    symbols = subprocess.check_output(["nm", "-u", str(executable)], text=True)
    forbidden = [
        r"AXUIElement", r"AXIsProcessTrusted", r"CGWindowListCreateImage", r"CGDisplayCreateImage",
        r"SCStream", r"SCScreenshotManager", r"NSURLSession", r"NWConnection",
        r"\b_(?:socket|connect|execve|system|popen)\b"
    ]
    for pattern in forbidden:
        if re.search(pattern, symbols):
            raise ValueError("Unexpected sensitive API import: " + pattern)
    libraries = subprocess.check_output(["otool", "-L", str(executable)], text=True)
    for line in libraries.splitlines()[1:]:
        library = line.strip().split(" (", 1)[0]
        if not library.startswith(("/System/Library/", "/usr/lib/")):
            raise ValueError("Unexpected non-system dynamic library: " + library)
    print("Signature, sandbox-only entitlements, hardened runtime, imports and dynamic libraries verified.")


if __name__ == "__main__":
    try:
        verify_app(sys.argv[1])
    except (ValueError, OSError, subprocess.CalledProcessError) as error:
        sys.exit(str(error))

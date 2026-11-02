#!/usr/bin/env python3
"""Validate and publish a local app without silent replacement or destructive rollback."""
import argparse
import os
from pathlib import Path
import shutil
import tempfile
import uuid
from atomic_publish import atomic_publish_no_replace, destination_lock
from verify_app import verify_app

class InstallRecoveryError(OSError):
    def __init__(self, backup, destination, original):
        self.backup = backup
        super().__init__("Publication failed; previous app is retained at " + str(backup) +
                         ". Destination was not overwritten during recovery: " + str(destination) +
                         ". Original failure: " + str(original))

def physical_directory_contains(parent, child):
    """Compare physical ancestors, including case/Unicode filesystem aliases."""
    if not parent.exists() or not parent.is_dir():
        return False
    expected = parent.stat()
    identity = (expected.st_dev, expected.st_ino)
    for candidate in (child, *child.parents):
        try:
            current = candidate.stat()
        except FileNotFoundError:
            continue
        if (current.st_dev, current.st_ino) == identity:
            return True
    return False

def canonical_install_paths(source, destination):
    source, destination = Path(source).absolute(), Path(destination).absolute()
    if source.is_symlink() or not source.is_dir():
        raise ValueError("Source must be a real app directory")
    if destination.suffix != ".app" or destination.is_symlink():
        raise ValueError("Destination must be an app directory, not a symlink")
    source = source.resolve(strict=True)
    destination = destination.parent.resolve() / destination.name
    if physical_directory_contains(source, destination) or physical_directory_contains(destination, source):
        raise ValueError("Source and destination must be physically separate")
    if any(path.is_symlink() for path in source.rglob("*")):
        raise ValueError("Source app must not contain symbolic links")
    return source, destination

def build_output_destination(repo):
    repo = Path(repo).resolve(strict=True)
    output = repo / "dist"
    if output.is_symlink():
        raise ValueError("Build output must not be redirected through a symlink")
    output.mkdir(exist_ok=True)
    if not output.is_dir() or output.resolve(strict=True) != output:
        raise ValueError("Unsafe build output directory")
    return output / "WhatsApp Privacy Cover.app"

def install_bundle(source, destination, replace=False, *, validator=verify_app):
    source, destination = canonical_install_paths(source, destination)
    destination.parent.mkdir(parents=True, exist_ok=True)
    with destination_lock(destination) as unchanged:
        if destination.is_symlink():
            raise ValueError("Destination became a symbolic link")
        if destination.exists() and not replace:
            raise FileExistsError("Destination exists; explicit --replace is required")
        if destination.exists() and not destination.is_dir():
            raise ValueError("Destination must be a directory")
        backup = None
        with tempfile.TemporaryDirectory(prefix=".privacy-cover-stage-", dir=destination.parent) as work:
            staged = Path(work) / "staged.app"
            shutil.copytree(source, staged, symlinks=True)
            validator(staged)
            unchanged()
            # A destination may have appeared while validation was running.
            if destination.is_symlink():
                raise ValueError("Destination became a symbolic link")
            if destination.exists():
                if not replace:
                    raise FileExistsError("Destination appeared; refusing replacement without --replace")
                if not destination.is_dir():
                    raise ValueError("Destination became a non-directory")
                backup = destination.with_name(destination.name + ".backup-" + uuid.uuid4().hex)
                atomic_publish_no_replace(destination, backup)
            try:
                unchanged()
                atomic_publish_no_replace(staged, destination)
            except (OSError, ValueError) as original:
                if backup is not None:
                    try:
                        unchanged()
                        atomic_publish_no_replace(backup, destination)
                    except (OSError, ValueError):
                        raise InstallRecoveryError(backup, destination, original) from original
                raise
        return backup

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", required=True, type=Path)
    parser.add_argument("--destination", required=True, type=Path)
    parser.add_argument("--replace", action="store_true")
    args = parser.parse_args()
    if os.geteuid() == 0:
        parser.exit(1, "Do not install as root or with sudo.\n")
    try:
        backup = install_bundle(args.source, args.destination, args.replace)
    except (OSError, ValueError) as error:
        parser.exit(1, str(error) + "\n")
    print("Installed:", args.destination)
    if backup is not None: print("Previous version retained at:", backup)
    print("The app was not launched.")

if __name__ == "__main__":
    main()

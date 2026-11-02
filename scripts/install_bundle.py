#!/usr/bin/env python3
"""Stage a local app copy; require opt-in replacement and retain the old bundle."""
import argparse
import os
from pathlib import Path
import shutil
import tempfile
import uuid
from verify_app import verify_app


def install_bundle(source, destination, replace=False, *, validator=verify_app):
    source, destination = Path(source).absolute(), Path(destination).absolute()
    if source.is_symlink() or not source.is_dir():
        raise ValueError("Source must be a real app directory")
    if any(path.is_symlink() for path in source.rglob("*")):
        raise ValueError("Source app must not contain symbolic links")
    if destination.suffix != ".app":
        raise ValueError("Destination must end in .app")
    if destination.is_symlink():
        raise ValueError("Refusing a symbolic-link destination")
    if source == destination or source in destination.parents or destination in source.parents:
        raise ValueError("Source and destination must be separate directories")
    if destination.exists() and not replace:
        raise FileExistsError("Destination exists; use --replace after quitting the old app")
    if destination.exists() and not destination.is_dir():
        raise ValueError("Destination must be a directory")
    destination.parent.mkdir(parents=True, exist_ok=True)
    backup = None
    with tempfile.TemporaryDirectory(prefix=".privacy-cover-stage-", dir=destination.parent) as work:
        staged = Path(work) / "staged.app"
        shutil.copytree(source, staged, symlinks=False)
        # Verify exactly what will be published, before disturbing an existing app.
        validator(staged)
        if destination.exists():
            backup = destination.with_name(destination.name + ".backup-" + uuid.uuid4().hex)
            os.replace(destination, backup)
        try:
            # Staging on the destination volume makes this rename atomic.
            os.replace(staged, destination)
        except OSError:
            if backup is not None:
                os.replace(backup, destination)
            raise
    return backup


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", required=True, type=Path)
    parser.add_argument("--destination", required=True, type=Path)
    parser.add_argument("--replace", action="store_true")
    args = parser.parse_args()
    try:
        backup = install_bundle(args.source, args.destination, args.replace)
    except (OSError, ValueError) as error:
        parser.exit(1, str(error) + "\n")
    print("Installed:", args.destination)
    if backup is not None:
        print("Previous version retained at:", backup)
    print("The app was not launched.")


if __name__ == "__main__":
    main()

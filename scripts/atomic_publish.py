"""Darwin atomic no-clobber publication and cooperating per-destination locks."""
import ctypes
from contextlib import contextmanager
import fcntl
import os
from pathlib import Path
import stat

DIR_FLAGS = os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW

@contextmanager
def destination_lock(destination, *, scope="publication"):
    destination = Path(destination)
    if scope not in {"publication", "build"}:
        raise ValueError("Unknown publication lock scope")
    parent_fd = os.open(destination.parent, DIR_FLAGS)
    lock_fd = None
    try:
        identity = os.fstat(parent_fd)
        def unchanged():
            current = os.stat(destination.parent, follow_symlinks=False)
            if (current.st_dev, current.st_ino) != (identity.st_dev, identity.st_ino):
                raise ValueError("Destination directory changed during publication")
        # One lock per physical parent directory avoids splitting locks across
        # case/Unicode aliases. Build orchestration uses a separate outer scope.
        name = ".privacy-cover-" + scope + ".lock"
        try:
            lock_fd = os.open(name, os.O_RDWR | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o600, dir_fd=parent_fd)
        except FileExistsError:
            lock_fd = os.open(name, os.O_RDWR | os.O_NOFOLLOW, dir_fd=parent_fd)
        info = os.fstat(lock_fd)
        if not stat.S_ISREG(info.st_mode) or info.st_nlink != 1 or info.st_uid != os.geteuid() or info.st_mode & 0o077:
            raise ValueError("Unsafe publication lock")
        fcntl.flock(lock_fd, fcntl.LOCK_EX)
        unchanged()
        yield unchanged
    finally:
        if lock_fd is not None: os.close(lock_fd)
        os.close(parent_fd)

def atomic_publish_no_replace(source, destination):
    source, destination = Path(source), Path(destination)
    # RENAME_EXCL is defined as 0x4 in the macOS SDK sys/stdio.h.
    libc = ctypes.CDLL(None, use_errno=True)
    rename = libc.renameatx_np
    rename.argtypes = [ctypes.c_int, ctypes.c_char_p, ctypes.c_int, ctypes.c_char_p, ctypes.c_uint]
    rename.restype = ctypes.c_int
    source_fd = os.open(source.parent, DIR_FLAGS)
    try:
        destination_fd = os.open(destination.parent, DIR_FLAGS)
        try:
            if rename(source_fd, os.fsencode(source.name), destination_fd, os.fsencode(destination.name), 0x4) != 0:
                error = ctypes.get_errno()
                raise OSError(error, os.strerror(error), str(destination))
        finally: os.close(destination_fd)
    finally: os.close(source_fd)

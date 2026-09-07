#!/usr/bin/python3
"""Watch the keyboard devices; when either Alt key is released, close the
end-4 overview and leave the `alttab` Hyprland submap. Self-exits on the
first Alt-release or after a safety timeout. Single-instance via a lockfile.

Needs read access to /dev/input/event* (the `input` group provides it).
"""
import glob
import os
import select
import struct
import subprocess
import sys
import time

KEY_LEFTALT = 56
KEY_RIGHTALT = 100
EV_KEY = 1
VALUE_RELEASE = 0

# struct input_event on 64-bit Linux: time (2x long) + type + code + value
FMT = "llHHi"
SZ = struct.calcsize(FMT)

LOCK = f"{os.environ.get('XDG_RUNTIME_DIR', '/tmp')}/hypr-alttab-watch.lock"
TIMEOUT_S = 15


def hypr(*args):
    subprocess.run(["hyprctl", "dispatch", *args],
                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def finish():
    hypr('hl.dsp.global("quickshell:overviewWorkspacesClose")')
    hypr('hl.dsp.submap("reset")')
    try:
        os.unlink(LOCK)
    except OSError:
        pass
    sys.exit(0)


def main():
    # Single instance: if a live lock exists, let the existing watcher handle it.
    if os.path.exists(LOCK):
        try:
            if time.time() - os.path.getmtime(LOCK) < TIMEOUT_S:
                return
        except OSError:
            pass
    open(LOCK, "w").close()

    fds = []
    for path in glob.glob("/dev/input/by-path/*-event-kbd"):
        try:
            fds.append(os.open(path, os.O_RDONLY | os.O_NONBLOCK))
        except OSError:
            pass
    if not fds:
        finish()

    deadline = time.monotonic() + TIMEOUT_S
    try:
        while time.monotonic() < deadline:
            ready, _, _ = select.select(fds, [], [], 0.3)
            for fd in ready:
                try:
                    buf = os.read(fd, SZ * 64)
                except OSError:
                    continue
                for off in range(0, len(buf) - SZ + 1, SZ):
                    _, _, etype, code, value = struct.unpack_from(FMT, buf, off)
                    if (etype == EV_KEY and value == VALUE_RELEASE
                            and code in (KEY_LEFTALT, KEY_RIGHTALT)):
                        finish()
        finish()  # timeout fallback
    finally:
        for fd in fds:
            os.close(fd)


if __name__ == "__main__":
    main()

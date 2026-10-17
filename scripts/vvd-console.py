#!/usr/bin/env python3
"""Talk to the Vega Virtual Device's emulator console (telnet-style, 127.0.0.1:5554).

The VVD is an Android-emulator (QEMU) build, so it keeps the emulator console.
Two console commands matter for CI:

  screenrecord screenshot <dir>      -> host-side PNG of the composited GL surface
  screenrecord start [opts] <file>   -> host-side WebM recording (stop with
  screenrecord stop                     `screenrecord stop`)

Usage:
  vvd-console.py "screenrecord screenshot /tmp/shots" ["another command" ...]

Env: VVD_CONSOLE_PORT (default 5554). Auth token is read from
~/.emulator_console_auth_token when it exists (empty token otherwise).
"""
import os
import socket
import sys
import time

port = int(os.environ.get("VVD_CONSOLE_PORT", "5554"))
token_file = os.path.expanduser("~/.emulator_console_auth_token")


def read_reply(s, timeout=15.0):
    """Read until the console prints a line starting with OK or KO."""
    s.settimeout(timeout)
    buf = ""
    end = time.time() + timeout
    while time.time() < end:
        try:
            chunk = s.recv(65536).decode(errors="replace")
        except socket.timeout:
            break
        if not chunk:
            break
        buf += chunk
        lines = [l.strip() for l in buf.splitlines()]
        if any(l == "OK" or l.startswith("KO") for l in lines):
            break
    return buf


def main(cmds):
    s = socket.create_connection(("127.0.0.1", port), timeout=10)
    banner = read_reply(s, 5)
    if "auth" in banner.lower() and os.path.exists(token_file):
        tok = open(token_file).read().strip()
        s.sendall(("auth %s\n" % tok).encode())
        r = read_reply(s, 5)
        if "KO" in r:
            print("console auth failed: " + r.strip(), file=sys.stderr)
    rc = 0
    for c in cmds:
        s.sendall((c + "\n").encode())
        r = read_reply(s, 30).strip()
        print("> %s\n%s" % (c, r))
        if "KO" in r:
            rc = 1
    try:
        s.sendall(b"quit\n")
    except OSError:
        pass
    s.close()
    return rc


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(2)
    sys.exit(main(sys.argv[1:]))

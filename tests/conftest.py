"""Shared fixtures: a stub `vega` CLI on PATH and a fake emulator console."""
import os
import pathlib
import socket
import stat
import subprocess
import threading

import pytest

ROOT = pathlib.Path(__file__).resolve().parent.parent
SCRIPTS = ROOT / "scripts"


def run(cmd, env=None, timeout=30, **kw):
    e = os.environ.copy()
    if env:
        e.update(env)
    return subprocess.run(cmd, env=e, capture_output=True, text=True, timeout=timeout, **kw)


@pytest.fixture
def stub_vega(tmp_path):
    """A fake `vega` that appends its argv to calls.log and exits with $VEGA_STUB_RC."""
    bindir = tmp_path / "bin"
    bindir.mkdir()
    log = tmp_path / "calls.log"
    vega = bindir / "vega"
    vega.write_text(
        "#!/usr/bin/env bash\n"
        f'echo "$*" >> "{log}"\n'
        'echo "Injecting Button Press As Driver: ${@: -1} State: short"\n'
        'exit "${VEGA_STUB_RC:-0}"\n'
    )
    vega.chmod(vega.stat().st_mode | stat.S_IEXEC)
    env = {"PATH": f"{bindir}:{os.environ['PATH']}", "PRESS_GAP": "0"}
    return env, log


class FakeConsole:
    """Minimal Android-emulator console: banner, auth, screenrecord screenshot."""

    PNG = b"\x89PNG\r\n\x1a\n" + b"\0" * 100

    def __init__(self, token="s3cret"):
        self.token = token
        self.commands = []
        self.sock = socket.socket()
        self.sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        self.sock.bind(("127.0.0.1", 0))
        self.sock.listen(5)
        self.port = self.sock.getsockname()[1]
        self._stop = False
        self.t = threading.Thread(target=self._serve, daemon=True)
        self.t.start()

    def _serve(self):
        self.sock.settimeout(0.2)
        while not self._stop:
            try:
                conn, _ = self.sock.accept()
            except (socket.timeout, OSError):
                continue
            threading.Thread(target=self._handle, args=(conn,), daemon=True).start()

    def _handle(self, conn):
        f = conn.makefile("rwb", buffering=0)
        authed = self.token is None
        banner = "Android Console: type 'help' for a list of commands\r\n"
        if not authed:
            banner = ("Android Console: Authentication required\r\n"
                      "Android Console: type 'auth <auth_token>' to authenticate\r\n")
        f.write((banner + "OK\r\n").encode())
        for raw in f:
            line = raw.decode().strip()
            self.commands.append(line)
            if line == "quit":
                break
            if line.startswith("auth "):
                if line[5:] == self.token:
                    authed = True
                    f.write(b"OK\r\n")
                else:
                    f.write(b"KO: authentication token does not match\r\n")
                continue
            if not authed:
                f.write(b"KO: unauthenticated\r\n")
                continue
            if line.startswith("screenrecord screenshot "):
                d = pathlib.Path(line.split(" ", 2)[2])
                if d.is_dir():
                    (d / "Screenshot_1.png").write_bytes(self.PNG)
                    f.write(b"OK\r\n")
                else:
                    f.write(b"KO: no such directory\r\n")
            elif line.startswith("screenrecord "):
                f.write(b"OK\r\n")
            else:
                f.write(b"KO: unknown command, try 'help'\r\n")
        conn.close()

    def close(self):
        self._stop = True
        self.sock.close()


@pytest.fixture
def console(tmp_path):
    home = tmp_path / "home"
    home.mkdir()
    c = FakeConsole()
    (home / ".emulator_console_auth_token").write_text(c.token + "\n")
    yield c, {"HOME": str(home), "VVD_CONSOLE_PORT": str(c.port)}
    c.close()

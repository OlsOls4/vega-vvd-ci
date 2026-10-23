"""Regression test for the v0 bug: start-vvd.sh phase 2 ran `pkill -9 -x node`,
which also SIGKILLed a concurrent `npm ci` / `npm run build` (npm runs as `node`).
vvd-kill.sh must kill the CLI's tree + session and nothing else."""
import os
import re
import shutil
import subprocess
import time

import pytest
from conftest import SCRIPTS, run

KILL = str(SCRIPTS / "vvd-kill.sh")


def alive(pid):
    try:
        with open(f"/proc/{pid}/stat") as f:
            return f.read().split(")")[-1].split()[0] != "Z"
    except FileNotFoundError:
        return False


@pytest.fixture
def fake_node(tmp_path):
    """A binary literally named `node` (comm == node), like npm on a runner."""
    p = tmp_path / "node"
    shutil.copy(shutil.which("sleep"), p)
    return str(p)


def test_kills_cli_tree_and_session_but_not_unrelated_node(tmp_path, fake_node):
    # Unrelated "user build": a process named node, started first.
    canary = subprocess.Popen([fake_node, "300"])
    # Fake CLI in its own session (start-vvd.sh uses setsid): a `node` child,
    # a grandchild, and a double-forked helper that is reparented away.
    cli = subprocess.Popen(
        ["bash", "-c", f'"{fake_node}" 300 & (sleep 300 &) ; bash -c "sleep 300" & wait'],
        start_new_session=True)
    emu = subprocess.Popen(["sleep", "300"])  # stands in for the emulator
    time.sleep(0.5)
    session = [int(p) for p in run(["pgrep", "-s", str(cli.pid)]).stdout.split()]
    assert len(session) >= 4, session

    # Sanity: the old v0 command would have matched the canary.
    assert str(canary.pid) in run(["pgrep", "-x", "node"]).stdout.split()

    r = run([KILL, str(cli.pid), str(emu.pid)])
    assert r.returncode == 0, r.stderr
    time.sleep(0.5)
    cli.poll(); emu.poll()
    try:
        assert alive(canary.pid), "vvd-kill.sh killed an unrelated `node` process"
        for p in session + [emu.pid]:
            assert not alive(p), f"pid {p} from the CLI session/emulator survived"
    finally:
        canary.kill()
        for p in session:
            try:
                os.kill(p, 9)
            except ProcessLookupError:
                pass


def test_does_not_kill_callers_session(tmp_path, fake_node):
    """If the CLI is NOT a session leader, the session sweep must be skipped."""
    sib = subprocess.Popen([fake_node, "300"])            # same session as us
    cli = subprocess.Popen(["sleep", "300"])              # not a session leader
    try:
        r = run([KILL, str(cli.pid)], {"VVD_KILL_DRYRUN": "1"})
        pids = r.stdout.split()
        assert str(cli.pid) in pids
        assert str(sib.pid) not in pids
        assert str(os.getpid()) not in pids
    finally:
        sib.kill(); cli.kill()


def test_rejects_bad_args():
    assert run([KILL]).returncode == 2
    assert run([KILL, "abc"]).returncode == 2


def test_start_vvd_never_pkills_node():
    src = (SCRIPTS / "start-vvd.sh").read_text()
    code = "\n".join(l.split("#")[0] for l in src.splitlines())
    assert not re.search(r"pkill[^\n]*\bnode\b", code)
    assert not re.search(r"killall[^\n]*\bnode\b", code)
    assert "vvd-kill.sh" in code

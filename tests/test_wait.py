import time
from conftest import SCRIPTS, run

WAIT = str(SCRIPTS / "wait-vvd.sh")


def _out(tmp_path, code=None):
    out = tmp_path / "artifacts"
    (out / "logs").mkdir(parents=True)
    (out / "logs" / "start-vvd.log").write_text("[start-vvd] VVD ready (61s)\n")
    if code is not None:
        (out / "vvd-exit").write_text(f"{code}\n")
    return out


def test_pass_when_boot_exit_0(tmp_path):
    out = _out(tmp_path, 0)
    r = run([WAIT, "10"], {"OUT": str(out), "VVD_WAIT_POLL": "0.1"})
    assert r.returncode == 0, r.stdout
    assert "VVD ready" in r.stdout  # boot log is replayed


def test_fail_when_boot_exit_nonzero(tmp_path):
    out = _out(tmp_path, 1)
    r = run([WAIT, "10"], {"OUT": str(out), "VVD_WAIT_POLL": "0.1"})
    assert r.returncode == 1
    assert "failed to boot" in r.stdout


def test_timeout_when_never_finishes(tmp_path):
    out = _out(tmp_path)
    t0 = time.time()
    r = run([WAIT, "1"], {"OUT": str(out), "VVD_WAIT_POLL": "0.1"})
    assert r.returncode == 1
    assert "did not finish" in r.stdout
    assert time.time() - t0 < 5


def test_waits_for_late_finish(tmp_path):
    import subprocess, os
    out = _out(tmp_path)
    env = dict(os.environ, OUT=str(out), VVD_WAIT_POLL="0.1")
    p = subprocess.Popen([WAIT, "10"], env=env, stdout=subprocess.PIPE, text=True)
    time.sleep(0.5)
    (out / "vvd-exit").write_text("0\n")
    assert p.wait(timeout=5) == 0


def test_rejects_non_numeric_timeout(tmp_path):
    assert run([WAIT, "soon"], {"OUT": str(_out(tmp_path, 0))}).returncode == 2

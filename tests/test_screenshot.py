from conftest import SCRIPTS, run, FakeConsole

SHOT = str(SCRIPTS / "screenshot.sh")


def test_screenshot_moves_png_to_target(console, tmp_path):
    _, env = console
    target = tmp_path / "out" / "nested" / "home.png"
    r = run([SHOT, str(target)], env)
    assert r.returncode == 0, r.stdout + r.stderr
    assert target.read_bytes() == FakeConsole.PNG
    assert "saved" in r.stdout


def test_screenshot_fails_when_no_png(console, tmp_path):
    c, env = console
    # Console answers OK but never writes a file.

    def handle(conn):
        f = conn.makefile("rwb", buffering=0)
        f.write(b"Android Console\r\nOK\r\n")
        for raw in f:
            if raw.strip() == b"quit":
                break
            f.write(b"OK\r\n")
        conn.close()
    c._handle = handle
    target = tmp_path / "x.png"
    r = run([SHOT, str(target)], dict(env, SHOT_TRIES="2"))
    assert r.returncode == 1
    assert "no screenshot produced" in r.stderr
    assert not target.exists()


def test_screenshot_requires_arg():
    assert run([SHOT]).returncode != 0

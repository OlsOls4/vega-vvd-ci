import sys
from conftest import SCRIPTS, run, FakeConsole

CONSOLE = [sys.executable, str(SCRIPTS / "vvd-console.py")]


def test_auth_then_command_ok(console, tmp_path):
    c, env = console
    shots = tmp_path / "shots"
    shots.mkdir()
    r = run(CONSOLE + [f"screenrecord screenshot {shots}"], env)
    assert r.returncode == 0, r.stdout + r.stderr
    assert c.commands[0] == f"auth {c.token}"
    assert (shots / "Screenshot_1.png").exists()
    assert c.commands[-1] == "quit"


def test_ko_reply_gives_exit_1(console):
    _, env = console
    r = run(CONSOLE + ["no-such-command"], env)
    assert r.returncode == 1
    assert "KO" in r.stdout


def test_multiple_commands_one_failing(console, tmp_path):
    c, env = console
    r = run(CONSOLE + ["screenrecord stop", "bogus"], env)
    assert r.returncode == 1
    assert "screenrecord stop" in c.commands and "bogus" in c.commands


def test_bad_token_reported(console, tmp_path):
    c, env = console
    (tmp_path / "home" / ".emulator_console_auth_token").write_text("wrong\n")
    r = run(CONSOLE + ["screenrecord stop"], env)
    assert "console auth failed" in r.stderr
    assert r.returncode == 1  # unauthenticated command is KO


def test_no_auth_console():
    c = FakeConsole(token=None)
    try:
        r = run(CONSOLE + ["screenrecord stop"], {"VVD_CONSOLE_PORT": str(c.port), "HOME": "/nonexistent"})
        assert r.returncode == 0, r.stdout
        assert not any(x.startswith("auth") for x in c.commands)
    finally:
        c.close()


def test_usage_without_args():
    assert run(CONSOLE).returncode == 2

import pytest
from conftest import SCRIPTS, run

PRESS = str(SCRIPTS / "press.sh")


@pytest.mark.parametrize("name,code", [
    ("up", "KEY_UP"), ("down", "KEY_DOWN"), ("left", "KEY_LEFT"), ("right", "KEY_RIGHT"),
    ("select", "KEY_ENTER"), ("ok", "KEY_ENTER"), ("enter", "KEY_ENTER"),
    ("back", "KEY_BACK"), ("home", "KEY_HOMEPAGE"), ("menu", "KEY_MENU"),
    ("playpause", "KEY_PLAYPAUSE"), ("rewind", "KEY_REWIND"),
    ("fastforward", "KEY_FASTFORWARD"), ("ff", "KEY_FASTFORWARD"),
    ("KEY_VOLUMEUP", "KEY_VOLUMEUP"),  # raw codes pass through
])
def test_key_names_map_to_inputd_codes(stub_vega, name, code):
    env, log = stub_vega
    r = run([PRESS, name], env)
    assert r.returncode == 0, r.stderr
    assert log.read_text().split() == ["exec", "vda", "shell", "inputd-cli", "button_press", code]
    assert f"press {name} ({code}) rc=0" in r.stdout


def test_sequence_in_order(stub_vega):
    env, log = stub_vega
    r = run([PRESS, "right", "right", "select", "back"], env)
    assert r.returncode == 0
    codes = [l.split()[-1] for l in log.read_text().splitlines()]
    assert codes == ["KEY_RIGHT", "KEY_RIGHT", "KEY_ENTER", "KEY_BACK"]


@pytest.mark.parametrize("bad", ["sideways", "KEY_", "KEY_lower", "key_up"])
def test_unknown_key_exits_2_and_presses_nothing(stub_vega, bad):
    env, log = stub_vega
    r = run([PRESS, "right", bad], env)
    assert r.returncode == 2
    assert "unknown key" in r.stderr
    assert not log.exists(), "no key may be pressed when any key is invalid"


def test_no_args_is_usage_error(stub_vega):
    env, _ = stub_vega
    assert run([PRESS], env).returncode == 2


def test_failed_press_propagates(stub_vega):
    env, _ = stub_vega
    env = dict(env, VEGA_STUB_RC="1")
    r = run([PRESS, "up"], env)
    assert r.returncode == 1
    assert "rc=1" in r.stdout

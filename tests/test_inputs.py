import pytest
from conftest import SCRIPTS, run

V = str(SCRIPTS / "validate-inputs.sh")


def outputs(tmp_path, **env):
    gh = tmp_path / "gh_output"
    gh.write_text("")
    base = {"GITHUB_OUTPUT": str(gh), "GITHUB_WORKSPACE": "/ws", "IN_BOOT": "background",
            "IN_TIMEOUT": "480", "IN_CACHE": "true", "IN_SDK": "", "IN_OUT": "artifacts"}
    base.update(env)
    r = run(["bash", V], base)
    return r, dict(l.split("=", 1) for l in gh.read_text().splitlines() if "=" in l)


@pytest.mark.parametrize("boot", ["background", "foreground", "none"])
def test_valid_boot(tmp_path, boot):
    r, o = outputs(tmp_path, IN_BOOT=boot)
    assert r.returncode == 0, r.stdout
    assert o["out"] == "/ws/artifacts"
    assert o["display"]


@pytest.mark.parametrize("field,val", [
    ("IN_BOOT", "backgorund"), ("IN_BOOT", "true"), ("IN_BOOT", "Background"),
    ("IN_TIMEOUT", "abc"), ("IN_TIMEOUT", "0"), ("IN_TIMEOUT", "-5"),
    ("IN_CACHE", "yes"), ("IN_SDK", "latest"), ("IN_SDK", "0.24; rm -rf /"),
])
def test_invalid_inputs_fail_with_annotation(tmp_path, field, val):
    r, _ = outputs(tmp_path, **{field: val})
    assert r.returncode == 1
    assert "::error" in r.stdout


def test_absolute_artifacts_dir(tmp_path):
    _, o = outputs(tmp_path, IN_OUT="/tmp/vvd")
    assert o["out"] == "/tmp/vvd"


def test_cache_key_pinned_vs_latest(tmp_path):
    _, o = outputs(tmp_path, IN_SDK="0.24.12112")
    assert o["sdk-key"] == "0.24.12112"
    _, o = outputs(tmp_path, IN_SDK="")
    assert o["sdk-key"].startswith("latest-20")  # month bucket, e.g. latest-2026-10

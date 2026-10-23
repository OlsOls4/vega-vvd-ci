import shutil
import subprocess

import pytest
from conftest import SCRIPTS, run

SHEET = str(SCRIPTS / "contact-sheet.sh")
needs_ffmpeg = pytest.mark.skipif(not shutil.which("ffmpeg"), reason="ffmpeg not installed")


@needs_ffmpeg
def test_tiles_shots_into_one_png(tmp_path):
    shots = []
    for i, name in enumerate(["home", "app-launched", "focus-right"], 1):
        p = tmp_path / f"{i:02d}-{name}.png"
        subprocess.run(["ffmpeg", "-v", "error", "-f", "lavfi", "-i", "color=c=blue:s=320x180",
                        "-frames:v", "1", str(p)], check=True)
        shots.append(str(p))
    out = tmp_path / "sheet.png"
    r = run([SHEET, str(out), *shots], {"SHEET_COLS": "2", "SHEET_W": "160"})
    assert r.returncode == 0, r.stderr
    assert "3 tiles, 2x2" in r.stdout
    probe = subprocess.run(["ffprobe", "-v", "error", "-show_entries", "stream=width,height",
                            "-of", "csv=p=0", str(out)], capture_output=True, text=True, check=True)
    w, h = map(int, probe.stdout.strip().split(","))
    assert w > 2 * 160 and h > 2 * 90


def test_needs_shots(tmp_path):
    assert run([SHEET, str(tmp_path / "x.png")]).returncode == 2

import os
import subprocess
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
SCRIPT = REPO_ROOT / "tools" / "scripts" / "synth_vivado.sh"


def test_vivado_dry_run_validates_source_manifest(tmp_path):
    out_dir = tmp_path / "vivado_out"
    env = os.environ.copy()
    env.update(
        {
            "VIVADO_DRY_RUN": "1",
            "VIVADO_PART": "xc7a35tcpg236-1",
            "VIVADO_OUT_DIR": str(out_dir),
        }
    )

    result = subprocess.run(
        [str(SCRIPT)],
        cwd=REPO_ROOT,
        env=env,
        check=True,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
    )

    assert "VIVADO DRY-RUN gpu_core (xc7a35tcpg236-1)" in result.stdout
    assert "Vivado Tcl:" in result.stdout
    assert "Sources: 27" in result.stdout
    assert not out_dir.exists()


def test_vivado_script_still_requires_part_in_dry_run(tmp_path):
    env = os.environ.copy()
    env.update(
        {
            "VIVADO_DRY_RUN": "1",
            "VIVADO_OUT_DIR": str(tmp_path),
        }
    )
    env.pop("VIVADO_PART", None)

    result = subprocess.run(
        [str(SCRIPT)],
        cwd=REPO_ROOT,
        env=env,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
    )

    assert result.returncode == 2
    assert "VIVADO_PART is required" in result.stdout

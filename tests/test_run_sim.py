import os
import subprocess
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
SCRIPT = REPO_ROOT / "tools" / "scripts" / "run_sim.sh"


def run_sim_env(env_updates):
    env = os.environ.copy()
    env.update(env_updates)
    return subprocess.run(
        [str(SCRIPT)],
        cwd=REPO_ROOT,
        env=env,
        check=False,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
    )


def listed_tests(output):
    return [line.strip() for line in output.splitlines() if line.strip()]


def test_list_sim_tests_has_no_build_side_effects(tmp_path):
    out_dir = tmp_path / "sim_out"
    result = run_sim_env({"SIM_LIST": "1", "SIM_OUT_DIR": str(out_dir)})

    assert result.returncode == 0
    tests = listed_tests(result.stdout)
    assert "tb_gpu_core_command_vector_add" in tests
    assert "tb_load_store_unit" in tests
    assert tests == sorted(tests)
    assert not out_dir.exists()


def test_sim_test_selection_lists_exact_test(tmp_path):
    result = run_sim_env(
        {
            "SIM_LIST": "1",
            "SIM_TEST": "tb_simd_alu",
            "SIM_OUT_DIR": str(tmp_path / "sim_out"),
        }
    )

    assert result.returncode == 0
    assert listed_tests(result.stdout) == ["tb_simd_alu"]


def test_sim_glob_selection_lists_matching_tests(tmp_path):
    result = run_sim_env(
        {
            "SIM_LIST": "1",
            "SIM_GLOB": "*command_vector*",
            "SIM_OUT_DIR": str(tmp_path / "sim_out"),
        }
    )

    assert result.returncode == 0
    assert listed_tests(result.stdout) == ["tb_gpu_core_command_vector_add"]


def test_sim_selection_rejects_ambiguous_filters(tmp_path):
    result = run_sim_env(
        {
            "SIM_LIST": "1",
            "SIM_TEST": "tb_simd_alu",
            "SIM_GLOB": "*simd*",
            "SIM_OUT_DIR": str(tmp_path / "sim_out"),
        }
    )

    assert result.returncode == 2
    assert "mutually exclusive" in result.stdout


def test_sim_selection_rejects_empty_match(tmp_path):
    result = run_sim_env(
        {
            "SIM_LIST": "1",
            "SIM_TEST": "tb_does_not_exist",
            "SIM_OUT_DIR": str(tmp_path / "sim_out"),
        }
    )

    assert result.returncode == 2
    assert "No simulation testbenches matched" in result.stdout

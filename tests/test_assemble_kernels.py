import importlib.util
import sys
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
SCRIPT_PATH = REPO_ROOT / "tools" / "scripts" / "assemble_kernels.py"


def load_script():
    spec = importlib.util.spec_from_file_location("assemble_kernels", SCRIPT_PATH)
    assert spec is not None
    assert spec.loader is not None
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


def test_orphan_memh_detection(tmp_path):
    script = load_script()
    source = tmp_path / "kept.kgpu"
    fixture = tmp_path / "kept.memh"
    orphan = tmp_path / "orphan.memh"
    source.write_text("END\n")
    fixture.write_text("04000000\n")
    orphan.write_text("00000000\n")

    old_kernel_dir = script.KERNEL_DIR
    script.KERNEL_DIR = tmp_path
    try:
        assert script.orphan_memh_files() == [orphan]
    finally:
        script.KERNEL_DIR = old_kernel_dir

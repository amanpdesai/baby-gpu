import importlib.util
import subprocess
import sys
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
ASM_PATH = REPO_ROOT / "tools" / "assembler" / "kgpu_asm.py"


def load_assembler():
    spec = importlib.util.spec_from_file_location("kgpu_asm", ASM_PATH)
    assert spec is not None
    assert spec.loader is not None
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


def assemble_text(tmp_path, source):
    asm = load_assembler()
    source_path = tmp_path / "kernel.kgpu"
    source_path.write_text(source)
    return asm.assemble(source_path)


def test_encodes_current_isa_forms(tmp_path):
    words = assemble_text(
        tmp_path,
        """
        NOP
        END
        MOVI R1, 0x123
        MOVSR R2, GLOBAL_ID_X
        ADD R3, R1, R2
        CMP.LTU R4, R1, R2
        LOAD R5, [R6 + 16]
        STORE [R6 + 20], R5
        PSTORE16 [R6 + 2], R5, R4
        """,
    )

    assert words == [
        0x00000000,
        0x04000000,
        0x08400123,
        0x0C810000,
        0x10C48000,
        0x25048002,
        0x19580010,
        0x1D580014,
        0x49590002,
    ]


def test_resolves_forward_and_backward_branch_labels(tmp_path):
    words = assemble_text(
        tmp_path,
        """
        start:
          BRA R1, done
          END
        done:
          BRA R0, start
        """,
    )

    assert words == [
        0x28400001,
        0x04000000,
        0x283FFFFD,
    ]


def test_rejects_out_of_range_immediate_with_source_location(tmp_path):
    source_path = tmp_path / "bad.kgpu"
    source_path.write_text("MOVI R1, 0x40000\n")

    result = subprocess.run(
        [sys.executable, str(ASM_PATH), str(source_path)],
        check=False,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )

    assert result.returncode == 1
    assert "bad.kgpu:1" in result.stderr
    assert "MOVI immediate" in result.stderr


def test_rejects_empty_operands(tmp_path):
    source_path = tmp_path / "bad.kgpu"
    source_path.write_text("ADD R1,, R2, R3\n")

    result = subprocess.run(
        [sys.executable, str(ASM_PATH), str(source_path)],
        check=False,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )

    assert result.returncode == 1
    assert "bad.kgpu:1" in result.stderr
    assert "empty operand" in result.stderr


def test_rejects_unknown_special_register(tmp_path):
    source_path = tmp_path / "bad.kgpu"
    source_path.write_text("MOVSR R1, 0x0c\n")

    result = subprocess.run(
        [sys.executable, str(ASM_PATH), str(source_path)],
        check=False,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )

    assert result.returncode == 1
    assert "bad.kgpu:1" in result.stderr
    assert "unknown special register" in result.stderr


def test_cli_writes_memh_file(tmp_path):
    source_path = tmp_path / "kernel.kgpu"
    output_path = tmp_path / "kernel.memh"
    source_path.write_text("MOVI R1, 7\nEND\n")

    result = subprocess.run(
        [sys.executable, str(ASM_PATH), str(source_path), "-o", str(output_path)],
        check=False,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )

    assert result.returncode == 0
    assert result.stdout == ""
    assert result.stderr == ""
    assert output_path.read_text() == "08400007\n04000000\n"

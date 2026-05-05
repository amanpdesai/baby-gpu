import re
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
READMEMH_RE = re.compile(r'\$readmemh\s*\(\s*"([^"]+\.memh)"')
RETIRED_HELPER_RE = re.compile(r"\b(kernel_asm_pkg|kgpu_[a-z0-9_]+)\b")


def referenced_memh_paths():
    paths = []
    for source_path in sorted((REPO_ROOT / "tb").rglob("*.sv")):
        text = source_path.read_text()
        for match in READMEMH_RE.finditer(text):
            fixture_path = REPO_ROOT / match.group(1)
            paths.append((source_path, fixture_path))
    return paths


def test_testbench_memh_references_are_checked_kernel_fixtures():
    references = referenced_memh_paths()

    assert references, "expected testbenches to reference checked kernel fixtures"
    for source_path, fixture_path in references:
        assert fixture_path.is_relative_to(REPO_ROOT / "tests" / "kernels"), source_path
        assert fixture_path.exists(), f"{source_path} references missing {fixture_path}"
        assert fixture_path.with_suffix(".kgpu").exists(), (
            f"{source_path} references {fixture_path} without matching .kgpu source"
        )


def test_testbench_rtl_does_not_use_retired_kernel_helpers():
    offenders = []
    for source_path in sorted((REPO_ROOT / "tb").rglob("*.sv")):
        text = source_path.read_text()
        match = RETIRED_HELPER_RE.search(text)
        if match:
            offenders.append(f"{source_path.relative_to(REPO_ROOT)}:{match.group(1)}")

    assert offenders == []

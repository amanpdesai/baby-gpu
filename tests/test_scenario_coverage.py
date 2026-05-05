import json
import re
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
MANIFEST = REPO_ROOT / "tests" / "scenario_coverage.json"
REQUIRED_FIELDS = {"id", "description", "tests"}
PATH_FIELDS = ("tests", "kernels", "formal")
KERNEL_MEMH_LITERAL_RE = re.compile(r'"(tests/kernels/[^"]+\.memh)"')


def load_manifest():
    return json.loads(MANIFEST.read_text())


def test_scenario_coverage_manifest_is_well_formed():
    manifest = load_manifest()
    assert manifest["version"] == 1
    scenarios = manifest["scenarios"]
    assert scenarios

    seen_ids = set()
    for scenario in scenarios:
        missing = REQUIRED_FIELDS - scenario.keys()
        assert not missing, f"{scenario.get('id', '<missing id>')} missing {sorted(missing)}"
        assert scenario["id"] not in seen_ids, f"duplicate scenario id {scenario['id']}"
        seen_ids.add(scenario["id"])
        assert scenario["description"].strip()
        assert scenario["tests"], f"{scenario['id']} must reference at least one simulation test"

    for waiver in manifest.get("formal_out_of_scope", []):
        assert waiver["path"].startswith("formal/scripts/")
        assert waiver["reason"].strip()

    for waiver in manifest.get("test_out_of_scope", []):
        assert waiver["path"].startswith(("tb/unit/", "tb/integration/"))
        assert waiver["reason"].strip()


def test_scenario_coverage_references_existing_artifacts():
    manifest = load_manifest()
    for scenario in manifest["scenarios"]:
        for field in PATH_FIELDS:
            for rel_path in scenario.get(field, []):
                path = REPO_ROOT / rel_path
                assert path.exists(), f"{scenario['id']} references missing {field} artifact {rel_path}"


def test_scenario_coverage_uses_expected_artifact_roots():
    manifest = load_manifest()
    expected_roots = {
        "tests": ("tb/unit/", "tb/integration/"),
        "kernels": ("tests/kernels/",),
        "formal": ("formal/scripts/",),
    }

    for scenario in manifest["scenarios"]:
        for field, roots in expected_roots.items():
            for rel_path in scenario.get(field, []):
                assert rel_path.startswith(roots), (
                    f"{scenario['id']} has {field} artifact outside expected roots: {rel_path}"
                )


def test_scenario_kernel_sources_have_generated_memh_files():
    manifest = load_manifest()
    for scenario in manifest["scenarios"]:
        for rel_path in scenario.get("kernels", []):
            source_path = REPO_ROOT / rel_path
            fixture_path = source_path.with_suffix(".memh")
            assert fixture_path.exists(), (
                f"{scenario['id']} references kernel source without generated memh: {rel_path}"
            )


def test_testbench_kernel_fixtures_are_claimed_by_scenarios():
    manifest = load_manifest()
    covered_kernels = {
        kernel for scenario in manifest["scenarios"] for kernel in scenario.get("kernels", [])
    }

    for source_path in (REPO_ROOT / "tb").rglob("*.sv"):
        for match in KERNEL_MEMH_LITERAL_RE.finditer(source_path.read_text()):
            fixture = match.group(1)
            kernel = str(Path(fixture).with_suffix(".kgpu"))
            assert kernel in covered_kernels, (
                f"{source_path.relative_to(REPO_ROOT)} references {fixture}, but {kernel} is not "
                "claimed by tests/scenario_coverage.json"
            )


def test_active_sim_testbenches_are_accounted_for_by_scenarios():
    manifest = load_manifest()
    active_tests = {str(path.relative_to(REPO_ROOT)) for path in (REPO_ROOT / "tb").rglob("tb_*.sv")}
    covered_tests = {test for scenario in manifest["scenarios"] for test in scenario.get("tests", [])}
    waived_tests = {waiver["path"] for waiver in manifest.get("test_out_of_scope", [])}

    assert covered_tests <= active_tests, f"unknown simulation tests: {sorted(covered_tests - active_tests)}"
    assert waived_tests <= active_tests, f"unknown simulation test waivers: {sorted(waived_tests - active_tests)}"
    assert not (covered_tests & waived_tests), (
        f"simulation tests cannot be both covered and waived: {sorted(covered_tests & waived_tests)}"
    )
    assert active_tests <= (covered_tests | waived_tests), (
        f"active simulation tests missing from scenario coverage manifest: "
        f"{sorted(active_tests - covered_tests - waived_tests)}"
    )


def test_active_formal_scripts_are_accounted_for_by_scenarios():
    manifest = load_manifest()
    active_scripts = {
        str(path.relative_to(REPO_ROOT))
        for path in (REPO_ROOT / "formal" / "scripts").glob("*.sby")
    }
    covered_scripts = {
        formal for scenario in manifest["scenarios"] for formal in scenario.get("formal", [])
    }
    waived_scripts = {waiver["path"] for waiver in manifest.get("formal_out_of_scope", [])}

    assert covered_scripts <= active_scripts, f"unknown formal scripts: {sorted(covered_scripts - active_scripts)}"
    assert waived_scripts <= active_scripts, f"unknown formal waivers: {sorted(waived_scripts - active_scripts)}"
    assert not (covered_scripts & waived_scripts), (
        f"formal scripts cannot be both covered and waived: {sorted(covered_scripts & waived_scripts)}"
    )
    assert active_scripts <= (covered_scripts | waived_scripts), (
        f"active formal scripts missing from scenario coverage manifest: "
        f"{sorted(active_scripts - covered_scripts - waived_scripts)}"
    )

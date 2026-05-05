import json
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
MANIFEST = REPO_ROOT / "tests" / "scenario_coverage.json"
REQUIRED_FIELDS = {"id", "description", "tests"}
PATH_FIELDS = ("tests", "kernels", "formal")


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

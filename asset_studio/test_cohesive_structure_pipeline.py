"""Deterministic conformance tests for cohesive structure alignment."""

import json
import sys
import tempfile
import unittest
from pathlib import Path

from PIL import Image, ImageDraw


HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))

from compose_asset_rig import find_asset, read_json  # noqa: E402
from compose_cohesive_structure import compose  # noqa: E402
from validate_asset_rig import validate  # noqa: E402


MANIFEST = HERE / "rigs_v2" / "resolved_rig_manifest.json"


def write_source(path: Path, controls: dict[str, list[int]] | None = None) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    image = Image.new("RGBA", (520, 560), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    draw.polygon(((70, 360), (260, 510), (450, 380), (430, 170), (260, 40), (90, 180)), fill=(221, 184, 112, 255))
    draw.polygon(((70, 360), (260, 510), (450, 380), (260, 230)), outline=(71, 43, 25, 255), width=12)
    image.save(path)
    metadata = {
        "backend": "local_test",
        "model": "deterministic_fixture",
        "prompt": "cohesive structure conformance fixture",
        "license": "project-generated test fixture",
        "synthetic": True,
        "ground_control_px": controls or {
            "south": [70, 360],
            "near": [260, 510],
            "east": [450, 380],
        },
    }
    path.with_suffix(".json").write_text(json.dumps(metadata, indent=2) + "\n", encoding="utf-8")


class CohesiveStructurePipelineTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temp_dir = tempfile.TemporaryDirectory(prefix="cohesive_structure_test_")
        self.root = Path(self.temp_dir.name)
        self.asset = find_asset(read_json(MANIFEST), "farmhouse")
        self.source = self.root / "farmhouse.png"
        write_source(self.source)

    def tearDown(self) -> None:
        self.temp_dir.cleanup()

    def compose_candidate(self) -> Path:
        candidate = self.root / "candidate"
        compose(self.asset, self.source, candidate, MANIFEST)
        return candidate

    def test_cohesive_source_aligns_and_validates(self) -> None:
        candidate = self.compose_candidate()
        result = validate(candidate, MANIFEST)
        self.assertTrue(result["ok"], result["errors"])
        recipe = read_json(candidate / "recipe.json")
        output = recipe["outputs"][0]
        self.assertEqual(output["ground_controls_local_px"]["near"], [output["anchor_x"], output["anchor_y"]])
        self.assertEqual(output["runtime_draw_scale"], 1.0)

    def test_validator_rejects_target_control_tampering(self) -> None:
        candidate = self.compose_candidate()
        recipe_path = candidate / "recipe.json"
        recipe = read_json(recipe_path)
        recipe["target_ground_controls_px"]["south"][0] += 4
        recipe_path.write_text(json.dumps(recipe, indent=2) + "\n", encoding="utf-8")
        result = validate(candidate, MANIFEST)
        self.assertFalse(result["ok"])
        self.assertTrue(any("target controls" in error for error in result["errors"]))

    def test_validator_rejects_local_control_tampering(self) -> None:
        candidate = self.compose_candidate()
        recipe_path = candidate / "recipe.json"
        recipe = read_json(recipe_path)
        recipe["outputs"][0]["ground_controls_local_px"]["east"][1] += 4
        recipe_path.write_text(json.dumps(recipe, indent=2) + "\n", encoding="utf-8")
        result = validate(candidate, MANIFEST)
        self.assertFalse(result["ok"])
        self.assertTrue(any("rig-relative anchor" in error for error in result["errors"]))

    def test_validator_rejects_elevation_scale_tampering(self) -> None:
        candidate = self.compose_candidate()
        recipe_path = candidate / "recipe.json"
        recipe = read_json(recipe_path)
        recipe["elevation_scale"] = 0.75
        recipe_path.write_text(json.dumps(recipe, indent=2) + "\n", encoding="utf-8")
        result = validate(candidate, MANIFEST)
        self.assertFalse(result["ok"])
        self.assertTrue(any("elevation scale" in error for error in result["errors"]))

    def test_compositor_rejects_collinear_source_controls(self) -> None:
        bad_source = self.root / "bad.png"
        write_source(bad_source, {
            "south": [100, 300],
            "near": [200, 300],
            "east": [300, 300],
        })
        with self.assertRaisesRegex(ValueError, "collinear"):
            compose(self.asset, bad_source, self.root / "bad_candidate", MANIFEST)


if __name__ == "__main__":
    unittest.main(verbosity=2)

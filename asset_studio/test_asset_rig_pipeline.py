"""End-to-end and fail-closed tests for the v2 dimetric asset rig.

These tests use only deterministic local images. They exercise the same input
contract that Terra or a pod must satisfy without spending generation credit.
"""

import copy
import json
import shutil
import sys
import tempfile
import unittest
from pathlib import Path

from PIL import Image, ImageDraw


HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))

from compose_asset_rig import compose, find_asset, read_json  # noqa: E402
from validate_asset_rig import validate  # noqa: E402


MANIFEST = HERE / "rigs_v2" / "resolved_rig_manifest.json"


def write_metadata(path: Path, extra: dict | None = None) -> None:
    metadata = {
        "backend": "local_test",
        "model": "deterministic_fixture",
        "prompt": "pipeline conformance fixture",
        "license": "project-generated test fixture",
    }
    if extra:
        metadata.update(extra)
    path.with_suffix(".json").write_text(json.dumps(metadata, indent=2) + "\n", encoding="utf-8")


def write_material(path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    image = Image.new("RGBA", (64, 64), (204, 168, 105, 255))
    draw = ImageDraw.Draw(image)
    for y in range(0, 64, 16):
        draw.line((0, y, 63, y), fill=(94, 56, 30, 255), width=2)
    image.save(path)
    write_metadata(path)


def write_module(path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    image = Image.new("RGBA", (80, 120), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    draw.rectangle((8, 8, 71, 115), fill=(104, 61, 31, 255), outline=(45, 27, 18, 255), width=5)
    image.save(path)
    write_metadata(path)


def write_prop(path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    image = Image.new("RGBA", (180, 240), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    draw.rectangle((35, 55, 145, 205), fill=(107, 80, 52, 255), outline=(43, 36, 31, 255), width=6)
    draw.ellipse((40, 180, 140, 220), fill=(91, 91, 83, 255), outline=(42, 42, 39, 255), width=5)
    image.save(path)
    write_metadata(path, {"contact_bbox_px": [40, 180, 100, 40]})


def write_oversized_prop(path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    image = Image.new("RGBA", (600, 240), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    draw.rectangle((0, 80, 599, 190), fill=(107, 80, 52, 255))
    draw.ellipse((250, 180, 350, 220), fill=(91, 91, 83, 255))
    image.save(path)
    write_metadata(path, {"contact_bbox_px": [250, 180, 100, 40]})


class AssetRigPipelineTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temp_dir = tempfile.TemporaryDirectory(prefix="asset_rig_test_")
        self.root = Path(self.temp_dir.name)
        self.manifest = read_json(MANIFEST)

    def tearDown(self) -> None:
        self.temp_dir.cleanup()

    def compose_synthetic(self, asset_id: str = "farmhouse") -> Path:
        candidate = self.root / f"synthetic_{asset_id}"
        compose(find_asset(self.manifest, asset_id), self.root / "unused_sources", candidate, True, MANIFEST)
        self.assertTrue(validate(candidate, MANIFEST)["ok"])
        return candidate

    def corrupt_recipe(self, candidate: Path, mutation) -> dict:
        recipe_path = candidate / "recipe.json"
        recipe = json.loads(recipe_path.read_text(encoding="utf-8"))
        mutation(recipe)
        recipe_path.write_text(json.dumps(recipe, indent=2) + "\n", encoding="utf-8")
        return validate(candidate, MANIFEST)

    def test_synthetic_golden_proofs_validate(self) -> None:
        for asset_id in ("farmhouse", "farmhouse_wide", "player_home_interior", "well"):
            with self.subTest(asset_id=asset_id):
                candidate = self.compose_synthetic(asset_id)
                self.assertEqual(validate(candidate, MANIFEST)["errors"], [])

    def test_independent_manifest_rejects_recipe_tampering(self) -> None:
        mutations = {
            "manifest hash": lambda recipe: recipe.__setitem__("resolved_manifest_sha256", "0" * 64),
            "asset hash": lambda recipe: recipe.__setitem__("resolved_asset_sha256", "0" * 64),
            "embedded geometry": lambda recipe: recipe["resolved_rig"]["canvas_size_px"].__setitem__(0, 1),
            "draw scale": lambda recipe: recipe["outputs"][0].__setitem__("draw_scale", 1.0),
            "runtime hash": lambda recipe: recipe["outputs"][0].__setitem__("runtime_sha256", "0" * 64),
            "source hash": lambda recipe: recipe["sources"][0].__setitem__("sha256", "0" * 64),
        }
        original = self.compose_synthetic()
        for label, mutation in mutations.items():
            with self.subTest(label=label):
                candidate = self.root / f"tampered_{label.replace(' ', '_')}"
                shutil.copytree(original, candidate)
                result = self.corrupt_recipe(candidate, mutation)
                self.assertFalse(result["ok"])
                self.assertTrue(result["errors"])

    def test_validator_rejects_opaque_pixels_outside_rig(self) -> None:
        candidate = self.compose_synthetic()
        recipe = read_json(candidate / "recipe.json")
        output_path = candidate / recipe["outputs"][0]["file"]
        with Image.open(output_path) as source:
            image = source.convert("RGBA")
        image.putpixel((0, 0), (255, 0, 255, 255))
        image.save(output_path)
        result = validate(candidate, MANIFEST)
        self.assertFalse(result["ok"])
        self.assertTrue(any("corner" in error or "escape" in error for error in result["errors"]))

    def test_runtime_outputs_are_exact_alpha_safe_reductions(self) -> None:
        for asset_id in ("farmhouse", "farmhouse_wide", "player_home_interior", "well"):
            with self.subTest(asset_id=asset_id):
                candidate = self.compose_synthetic(asset_id)
                recipe = read_json(candidate / "recipe.json")
                source_scale = int(recipe["resolved_rig"]["source_scale"])
                for output in recipe["outputs"]:
                    source = Image.open(candidate / output["file"]).convert("RGBA")
                    runtime = Image.open(candidate / output["runtime_file"]).convert("RGBA")
                    self.assertEqual(source.width % source_scale, 0)
                    self.assertEqual(source.height % source_scale, 0)
                    self.assertEqual(output["anchor_x"] % source_scale, 0)
                    self.assertEqual(output["anchor_y"] % source_scale, 0)
                    self.assertEqual(runtime.size, (source.width // source_scale, source.height // source_scale))
                    self.assertEqual(output["runtime_draw_scale"], 1.0)
                    self.assertTrue(any(0 < alpha < 255 for alpha in runtime.getchannel("A").get_flattened_data()))

    def test_validator_rejects_modified_runtime_output(self) -> None:
        candidate = self.compose_synthetic()
        recipe = read_json(candidate / "recipe.json")
        runtime_path = candidate / recipe["outputs"][0]["runtime_file"]
        runtime = Image.open(runtime_path).convert("RGBA")
        runtime.putpixel((0, 0), (255, 0, 255, 255))
        runtime.save(runtime_path)
        result = validate(candidate, MANIFEST)
        self.assertFalse(result["ok"])
        self.assertTrue(any("runtime output hash" in error or "runtime output corner" in error for error in result["errors"]))

    def test_validator_rejects_prop_pixels_outside_envelope(self) -> None:
        asset = find_asset(self.manifest, "well")
        source_root = self.root / "oversized_prop"
        write_oversized_prop(source_root / "props" / "well.png")
        candidate = self.root / "oversized_well"
        compose(asset, source_root, candidate, False, MANIFEST)
        result = validate(candidate, MANIFEST)
        self.assertFalse(result["ok"])
        self.assertTrue(any("prop opaque pixels escape" in error for error in result["errors"]))

    def test_real_flat_sources_and_provenance_validate(self) -> None:
        asset = find_asset(self.manifest, "farmhouse")
        source_root = self.root / "real_sources"
        material_ids = {surface["material"] for surface in asset["surfaces"] if surface["material"]}
        module_ids = {slot["module"] for slot in asset["slots"] if slot["kind"] != "contact"}
        for source_id in material_ids:
            write_material(source_root / "materials" / f"{source_id}.png")
        for source_id in module_ids:
            write_module(source_root / "modules" / f"{source_id}.png")
        candidate = self.root / "real_farmhouse"
        recipe = compose(asset, source_root, candidate, False, MANIFEST)
        self.assertTrue(validate(candidate, MANIFEST)["ok"])
        self.assertTrue(recipe["sources"])
        self.assertTrue(all(not source["synthetic"] for source in recipe["sources"]))
        self.assertTrue(all(source.get("metadata_sha256") for source in recipe["sources"]))

    def test_real_prop_uses_explicit_contact_landmark(self) -> None:
        asset = find_asset(self.manifest, "well")
        source_root = self.root / "real_prop_sources"
        write_prop(source_root / "props" / "well.png")
        candidate = self.root / "real_well"
        compose(asset, source_root, candidate, False, MANIFEST)
        result = validate(candidate, MANIFEST)
        self.assertTrue(result["ok"], result["errors"])

    def test_real_source_without_metadata_is_rejected(self) -> None:
        asset = find_asset(self.manifest, "well")
        source_root = self.root / "missing_metadata"
        source_path = source_root / "props" / "well.png"
        write_prop(source_path)
        source_path.with_suffix(".json").unlink()
        with self.assertRaisesRegex(ValueError, "missing source metadata"):
            compose(asset, source_root, self.root / "bad_well", False, MANIFEST)

    def test_prop_contact_landmark_outside_source_is_rejected(self) -> None:
        asset = find_asset(self.manifest, "well")
        source_root = self.root / "bad_contact"
        source_path = source_root / "props" / "well.png"
        write_prop(source_path)
        write_metadata(source_path, {"contact_bbox_px": [170, 230, 30, 30]})
        with self.assertRaisesRegex(ValueError, "outside the source image"):
            compose(asset, source_root, self.root / "bad_contact_well", False, MANIFEST)


if __name__ == "__main__":
    unittest.main(verbosity=2)

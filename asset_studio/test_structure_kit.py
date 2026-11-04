"""Regression coverage for the deterministic whitewash-and-thatch kit."""

from __future__ import annotations

import tempfile
import unittest
from pathlib import Path

from compose_asset_rig import find_asset, read_json
from compose_structure_kit import DEFAULT_KIT, compose
from validate_asset_rig import validate


HERE = Path(__file__).resolve().parent
MANIFEST = HERE / "rigs_v2" / "resolved_rig_manifest.json"
SOURCES = HERE / "sources_v2"


class StructureKitTests(unittest.TestCase):
    def test_farmhouse_profile_composes_and_validates(self) -> None:
        with tempfile.TemporaryDirectory(prefix="structure_kit_test_") as temporary:
            candidate = Path(temporary) / "farmhouse_wide"
            manifest = read_json(MANIFEST)
            recipe = compose(
                find_asset(manifest, "farmhouse_wide"),
                read_json(DEFAULT_KIT),
                SOURCES,
                candidate,
                MANIFEST,
            )
            result = validate(candidate, MANIFEST)
            self.assertEqual(recipe["pipeline"], "structure_kit")
            self.assertTrue(result["ok"], result["errors"])
            self.assertTrue((candidate / "final_runtime.png").is_file())

    def test_missing_profile_is_rejected(self) -> None:
        manifest = read_json(MANIFEST)
        with tempfile.TemporaryDirectory(prefix="structure_kit_test_") as temporary:
            with self.assertRaisesRegex(ValueError, "has no profile"):
                compose(
                    find_asset(manifest, "farmhouse"),
                    read_json(DEFAULT_KIT),
                    SOURCES,
                    Path(temporary) / "farmhouse",
                    MANIFEST,
                )


if __name__ == "__main__":
    unittest.main(verbosity=2)

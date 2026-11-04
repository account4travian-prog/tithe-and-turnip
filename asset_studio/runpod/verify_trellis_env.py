"""Verify the pinned TRELLIS runtime and report each package's import name."""

from __future__ import annotations

import importlib
import importlib.metadata
import json
from pathlib import Path

import torch


DISTRIBUTIONS: tuple[str, ...] = (
    "flash-attn",
    "nvdiffrast",
    "nvdiffrec-render",
    "cumesh",
    "o-voxel",
    "flex-gemm",
)


def distribution_imports(distribution_name: str) -> list[str]:
    package_map: dict[str, list[str]] = importlib.metadata.packages_distributions()
    normalized_name: str = distribution_name.lower().replace("_", "-")
    return sorted(
        package_name
        for package_name, owners in package_map.items()
        if any(owner.lower().replace("_", "-") == normalized_name for owner in owners)
    )


def main() -> None:
    assert torch.cuda.is_available(), "PyTorch cannot see CUDA"
    assert torch.version.cuda == "12.4", torch.version.cuda

    report: dict[str, object] = {
        "python_packages": {},
        "torch": torch.__version__,
        "cuda": torch.version.cuda,
        "gpu": torch.cuda.get_device_name(0),
    }
    package_report: dict[str, list[str]] = {}
    for distribution_name in DISTRIBUTIONS:
        import_names: list[str] = distribution_imports(distribution_name)
        assert import_names, f"No import package found for {distribution_name}"
        for import_name in import_names:
            importlib.import_module(import_name)
        package_report[distribution_name] = import_names

    importlib.import_module("trellis2")
    package_report["TRELLIS.2"] = ["trellis2"]
    report["python_packages"] = package_report

    output_path: Path = Path("/workspace/trellis2_import_report.json")
    output_path.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(output_path.read_text(encoding="utf-8"))


if __name__ == "__main__":
    main()


"""Run a reproducible 512-cubed TRELLIS image-to-3D experiment."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import shutil
import subprocess
import time
from pathlib import Path

os.environ["OPENCV_IO_ENABLE_OPENEXR"] = "1"
os.environ["PYTORCH_CUDA_ALLOC_CONF"] = "expandable_segments:True"
os.environ.setdefault("HF_HOME", "/workspace/huggingface")

import cv2
import imageio
import o_voxel
import torch
from PIL import Image
from trellis2.modules import image_feature_extractor
from trellis2.pipelines import Trellis2ImageTo3DPipeline
from trellis2.pipelines import samplers
from trellis2.pipelines.base import Pipeline
from trellis2.renderers import EnvMap
from trellis2.utils import render_utils


def _patch_dinov3_transformers_compatibility() -> None:
    """Bridge the DINOv3 encoder rename without modifying third-party source.

    TRELLIS commit 75fbf018 was written against a Transformers DINOv3 preview
    that exposed the encoder blocks as ``model.layer``. Current supported
    Transformers exposes the same blocks at ``model.model.layer``. Both forms
    execute the identical modules; only the containing attribute changed.
    """

    def _extract_features(extractor: object, image: torch.Tensor) -> torch.Tensor:
        model: object = getattr(extractor, "model")
        image_size: torch.Tensor = image.to(getattr(getattr(model, "embeddings"), "patch_embeddings").weight.dtype)
        hidden_states: torch.Tensor = getattr(model, "embeddings")(image_size, bool_masked_pos=None)
        position_embeddings: object = getattr(model, "rope_embeddings")(image_size)
        layers: object = getattr(model, "layer", None)
        if layers is None:
            layers = getattr(getattr(model, "model"), "layer")
        for layer_module in layers:
            hidden_states = layer_module(hidden_states, position_embeddings=position_embeddings)
        return torch.nn.functional.layer_norm(hidden_states, hidden_states.shape[-1:])

    image_feature_extractor.DinoV3FeatureExtractor.extract_features = _extract_features


_patch_dinov3_transformers_compatibility()


class Trellis2ImageTo3D512Pipeline(Trellis2ImageTo3DPipeline):
    """Load only 512 components and omit unnecessary BRIA background removal."""

    model_names_to_load: list[str] = [
        "sparse_structure_flow_model",
        "sparse_structure_decoder",
        "shape_slat_flow_model_512",
        "shape_slat_decoder",
        "tex_slat_flow_model_512",
        "tex_slat_decoder",
    ]

    @classmethod
    def from_pretrained(
        cls, path: str, config_file: str = "pipeline.json"
    ) -> "Trellis2ImageTo3D512Pipeline":
        # Call the generic loader directly so the selected model-name list is
        # honored, then mirror Microsoft's pipeline wiring except for BRIA's
        # RMBG-2.0. Every accepted project input already has transparency, so
        # loading that separately licensed non-commercial model is unnecessary.
        pipeline = Pipeline.from_pretrained.__func__(cls, path, config_file)
        args: dict[str, object] = pipeline._pretrained_args

        sparse_sampler: dict[str, object] = args["sparse_structure_sampler"]
        shape_sampler: dict[str, object] = args["shape_slat_sampler"]
        tex_sampler: dict[str, object] = args["tex_slat_sampler"]
        image_model: dict[str, object] = args["image_cond_model"]

        pipeline.sparse_structure_sampler = getattr(
            samplers, sparse_sampler["name"]
        )(**sparse_sampler["args"])
        pipeline.sparse_structure_sampler_params = sparse_sampler["params"]
        pipeline.shape_slat_sampler = getattr(samplers, shape_sampler["name"])(
            **shape_sampler["args"]
        )
        pipeline.shape_slat_sampler_params = shape_sampler["params"]
        pipeline.tex_slat_sampler = getattr(samplers, tex_sampler["name"])(
            **tex_sampler["args"]
        )
        pipeline.tex_slat_sampler_params = tex_sampler["params"]
        pipeline.shape_slat_normalization = args["shape_slat_normalization"]
        pipeline.tex_slat_normalization = args["tex_slat_normalization"]
        pipeline.image_cond_model = getattr(
            image_feature_extractor, image_model["name"]
        )(**image_model["args"])
        pipeline.rembg_model = None
        pipeline.low_vram = args.get("low_vram", True)
        pipeline.default_pipeline_type = "512"
        pipeline.pbr_attr_layout = {
            "base_color": slice(0, 3),
            "metallic": slice(3, 4),
            "roughness": slice(4, 5),
            "alpha": slice(5, 6),
        }
        pipeline._device = "cpu"
        return pipeline


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def git_head(repo: Path) -> str:
    return subprocess.check_output(
        ["git", "-C", str(repo), "rev-parse", "HEAD"], text=True
    ).strip()


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", type=Path, required=True)
    parser.add_argument("--output-dir", type=Path, required=True)
    parser.add_argument("--seed", type=int, default=42)
    parser.add_argument("--label", default="experiment")
    args = parser.parse_args()

    input_path: Path = args.input.resolve()
    output_dir: Path = args.output_dir.resolve()
    output_dir.mkdir(parents=True, exist_ok=True)
    copied_input: Path = output_dir / f"input{input_path.suffix.lower()}"
    if copied_input != input_path:
        shutil.copy2(input_path, copied_input)

    started_at: float = time.time()
    disk_before = shutil.disk_usage("/workspace")
    torch.cuda.reset_peak_memory_stats()

    repo_root = Path("/workspace/TRELLIS.2")
    env_image = cv2.imread(
        str(repo_root / "assets/hdri/forest.exr"), cv2.IMREAD_UNCHANGED
    )
    envmap = None
    if env_image is not None:
        envmap = EnvMap(
            torch.tensor(
                cv2.cvtColor(env_image, cv2.COLOR_BGR2RGB),
                dtype=torch.float32,
                device="cuda",
            )
        )
    else:
        print(
            "WARNING: this OpenCV build could not decode the tracked forest.exr; "
            "skipping the optional internal turntable because the PBR renderer "
            "requires an explicit environment map. Blender validation is unaffected.",
            flush=True,
        )

    image = Image.open(copied_input)
    assert "A" in image.getbands(), "Input must include an alpha channel"
    alpha_extrema: tuple[int, int] = image.getchannel("A").getextrema()
    assert alpha_extrema[0] < 255, "Input alpha channel must contain transparency"

    pipeline = Trellis2ImageTo3D512Pipeline.from_pretrained(
        "microsoft/TRELLIS.2-4B"
    )
    pipeline.cuda()

    mesh = pipeline.run(
        image,
        seed=args.seed,
        pipeline_type="512",
    )[0]
    mesh.simplify(16_777_216)

    video_path: Path | None = None
    if envmap is not None:
        video_path = output_dir / "preview.mp4"
        video = render_utils.make_pbr_vis_frames(
            render_utils.render_video(mesh, envmap=envmap)
        )
        imageio.mimsave(video_path, video, fps=15)

    glb = o_voxel.postprocess.to_glb(
        vertices=mesh.vertices,
        faces=mesh.faces,
        attr_volume=mesh.attrs,
        coords=mesh.coords,
        attr_layout=mesh.layout,
        voxel_size=mesh.voxel_size,
        aabb=[[-0.5, -0.5, -0.5], [0.5, 0.5, 0.5]],
        decimation_target=1_000_000,
        texture_size=4096,
        remesh=True,
        remesh_band=1,
        remesh_project=0,
        verbose=True,
    )
    glb_path = output_dir / "model.glb"
    # Pillow's optional WebP encoder is ABI-incompatible in the pinned pod
    # environment. PNG is natively supported by GLB consumers and keeps the
    # proof portable; only compression changes, never mesh geometry.
    glb.export(glb_path, extension_webp=False)

    elapsed_seconds: float = time.time() - started_at
    disk_after = shutil.disk_usage("/workspace")
    files: dict[str, dict[str, object]] = {}
    output_files: list[Path] = [copied_input, glb_path]
    if video_path is not None:
        output_files.append(video_path)
    for path in output_files:
        files[path.name] = {
            "bytes": path.stat().st_size,
            "sha256": sha256(path),
        }

    metadata: dict[str, object] = {
        "label": args.label,
        "input_source": str(input_path),
        "seed": args.seed,
        "pipeline_type": "512",
        "background_removal_model": None,
        "internal_preview_envmap": envmap is not None,
        "trellis_commit": git_head(repo_root),
        "torch": torch.__version__,
        "cuda": torch.version.cuda,
        "gpu": torch.cuda.get_device_name(0),
        "peak_cuda_bytes": torch.cuda.max_memory_allocated(),
        "elapsed_seconds": elapsed_seconds,
        "workspace_used_delta_bytes": disk_after.used - disk_before.used,
        "mesh_before_glb": {
            "vertices": int(mesh.vertices.shape[0]),
            "faces": int(mesh.faces.shape[0]),
        },
        "glb_settings": {
            "decimation_target": 1_000_000,
            "texture_size": 4096,
            "remesh": True,
            "extension_webp": False,
        },
        "files": files,
    }
    metadata_path = output_dir / "generation_metadata.json"
    metadata_path.write_text(json.dumps(metadata, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(metadata, indent=2), flush=True)


if __name__ == "__main__":
    main()

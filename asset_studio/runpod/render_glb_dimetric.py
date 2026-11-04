#!/usr/bin/env python3
"""Render one TRELLIS GLB through the game's fixed dimetric camera in Blender.

Run with Blender in background mode:
  blender --background --python render_glb_dimetric.py -- --input model.glb --output proof.png

This is an opaque, neutrally lit review renderer only. It does not alter the
GLB and deliberately uses the same 64x48 elevation as the Godot presentation
seam.
"""

from __future__ import annotations

import argparse
import json
import math
from pathlib import Path

import bpy
from mathutils import Vector


TILE_WIDTH: float = 64.0
TILE_HEIGHT: float = 48.0
RENDER_SIZE: int = 1024
MARGIN: float = 1.18


def parse_arguments() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--report", type=Path)
    return parser.parse_args(argv_after_double_dash())


def argv_after_double_dash() -> list[str]:
    arguments: list[str] = list(__import__("sys").argv)
    if "--" not in arguments:
        return []
    return arguments[arguments.index("--") + 1 :]


def reset_scene() -> None:
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for collection in (bpy.data.meshes, bpy.data.materials, bpy.data.cameras, bpy.data.lights):
        for datablock in collection:
            if datablock.users == 0:
                collection.remove(datablock)


def mesh_world_corners() -> tuple[list[Vector], int, int]:
    corners: list[Vector] = []
    vertex_count: int = 0
    triangle_count: int = 0
    for object_3d in bpy.context.scene.objects:
        if object_3d.type != "MESH":
            continue
        mesh = object_3d.data
        vertex_count += len(mesh.vertices)
        triangle_count += sum(len(polygon.vertices) - 2 for polygon in mesh.polygons)
        corners.extend(object_3d.matrix_world @ Vector(corner) for corner in object_3d.bound_box)
    if not corners:
        raise RuntimeError("The imported GLB contains no mesh geometry.")
    return corners, vertex_count, triangle_count


def force_opaque_materials() -> None:
    """Avoid a transparent source alpha map hiding an otherwise valid mesh."""
    for object_3d in bpy.context.scene.objects:
        if object_3d.type != "MESH":
            continue
        for material_slot in object_3d.material_slots:
            material = material_slot.material
            if material is None or not material.use_nodes:
                continue
            principled = material.node_tree.nodes.get("Principled BSDF")
            if principled is None:
                continue
            alpha_input = principled.inputs.get("Alpha")
            if alpha_input is None:
                continue
            for link in list(alpha_input.links):
                material.node_tree.links.remove(link)
            alpha_input.default_value = 1.0


def add_area_light(name: str, location: Vector, target: Vector, energy: float, size: float) -> None:
    light_data = bpy.data.lights.new(name=name, type="AREA")
    light_data.energy = energy
    light_data.shape = "DISK"
    light_data.size = size
    light_object = bpy.data.objects.new(name, light_data)
    bpy.context.collection.objects.link(light_object)
    light_object.location = location
    light_object.rotation_euler = (0.0, 0.0, 0.0)
    light_object.rotation_mode = "QUATERNION"
    light_object.rotation_quaternion = (target - location).to_track_quat("-Z", "Y")


def configure_camera(corners: list[Vector]) -> tuple[Vector, Vector, Vector, float]:
    minimum = Vector((min(point.x for point in corners), min(point.y for point in corners), min(point.z for point in corners)))
    maximum = Vector((max(point.x for point in corners), max(point.y for point in corners), max(point.z for point in corners)))
    target = (minimum + maximum) * 0.5

    elevation = math.asin(TILE_HEIGHT / TILE_WIDTH)
    horizontal = math.cos(elevation) / math.sqrt(2.0)
    camera_direction = Vector((-horizontal, -horizontal, math.sin(elevation))).normalized()
    camera_distance = max((maximum - minimum).length * 3.0, 3.0)

    camera_data = bpy.data.cameras.new("DimetricCamera")
    camera_data.type = "ORTHO"
    camera_object = bpy.data.objects.new("DimetricCamera", camera_data)
    bpy.context.collection.objects.link(camera_object)
    camera_object.location = target + camera_direction * camera_distance
    camera_object.rotation_mode = "QUATERNION"
    camera_object.rotation_quaternion = (target - camera_object.location).to_track_quat("-Z", "Y")
    bpy.context.scene.camera = camera_object

    forward = (target - camera_object.location).normalized()
    right = forward.cross(Vector((0.0, 0.0, 1.0))).normalized()
    up = right.cross(forward).normalized()
    horizontal_extent = max(abs((point - target).dot(right)) for point in corners)
    vertical_extent = max(abs((point - target).dot(up)) for point in corners)
    camera_data.ortho_scale = max(horizontal_extent, vertical_extent) * 2.0 * MARGIN
    return minimum, maximum, target, camera_data.ortho_scale


def configure_render(output_path: Path, target: Vector, maximum: Vector) -> None:
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE_NEXT"
    scene.render.resolution_x = RENDER_SIZE
    scene.render.resolution_y = RENDER_SIZE
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGB"
    scene.render.film_transparent = False
    scene.render.filepath = str(output_path)
    scene.view_settings.look = "AgX - Medium High Contrast"
    scene.world.color = (0.045, 0.045, 0.045)

    object_scale = max((maximum - target).length * 2.0, 1.0)
    add_area_light("Key", target + Vector((-object_scale, -object_scale, object_scale * 2.0)), target, 1200.0, object_scale * 2.5)
    add_area_light("Fill", target + Vector((object_scale, -object_scale, object_scale)), target, 700.0, object_scale * 2.0)
    add_area_light("Rim", target + Vector((object_scale, object_scale, object_scale * 1.5)), target, 900.0, object_scale * 1.5)


def main() -> None:
    arguments = parse_arguments()
    input_path: Path = arguments.input.resolve()
    output_path: Path = arguments.output.resolve()
    report_path: Path = arguments.report.resolve() if arguments.report else output_path.with_suffix(".json")
    if not input_path.is_file():
        raise FileNotFoundError(f"Missing GLB: {input_path}")
    output_path.parent.mkdir(parents=True, exist_ok=True)
    report_path.parent.mkdir(parents=True, exist_ok=True)

    reset_scene()
    bpy.ops.import_scene.gltf(filepath=str(input_path))
    force_opaque_materials()
    corners, vertex_count, triangle_count = mesh_world_corners()
    minimum, maximum, target, ortho_scale = configure_camera(corners)
    configure_render(output_path, target, maximum)
    bpy.ops.render.render(write_still=True)

    report = {
        "input": str(input_path),
        "output": str(output_path),
        "mesh_vertices": vertex_count,
        "mesh_triangles": triangle_count,
        "bounds_min": list(minimum),
        "bounds_max": list(maximum),
        "camera_target": list(target),
        "orthographic_scale": ortho_scale,
        "projection": {"tile_width": TILE_WIDTH, "tile_height": TILE_HEIGHT},
    }
    report_path.write_text(json.dumps(report, indent=2), encoding="utf-8")


if __name__ == "__main__":
    main()

"""Strip a flat background from generated asset images.

Usage:
    python strip_background.py input.png [--tolerance 24] [--out output.png]

Every generation in this pipeline is supposed to land on a flat, near-uniform
background so it can be keyed out later. This script samples the four corner
pixels, refuses to run when they are not close to uniform (so a real scene
background is not mangled), then flood-fills the connected background from
each corner into a transparent alpha channel. The opaque original is never
overwritten: the result is written to <name>_transparent.png by default.

Requires Pillow.
"""

import argparse
import os
import sys
from collections import deque

from PIL import Image, ImageChops

# Max per-channel difference (0-255) allowed between the corner pixels and
# their average, and later between a pixel and that background color. 24 is
# enough to absorb slight PNG recompression/gradient noise on a flat gray
# background without being wide enough to swallow typical subject colors,
# which differ from the background by much more than 24 in at least one
# channel.
DEFAULT_TOLERANCE = 24


def _corners(size: tuple[int, int]) -> list[tuple[int, int]]:
    w, h = size
    return [(0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1)]


def _max_channel_delta(a: tuple[int, int, int], b: tuple[int, int, int]) -> int:
    return max(abs(a[i] - b[i]) for i in range(3))


def _background_color(
    img: Image.Image, tolerance: int
) -> tuple[int, int, int] | None:
    """Return the average corner color, or None if the corners are not uniform."""
    rgb = img.convert("RGB")
    corner_pixels = [rgb.getpixel(xy) for xy in _corners(rgb.size)]
    average = tuple(
        round(sum(pixel[i] for pixel in corner_pixels) / len(corner_pixels))
        for i in range(3)
    )
    max_delta = max(_max_channel_delta(average, pixel) for pixel in corner_pixels)
    if max_delta > tolerance:
        print(
            f"WARN {img.filename or 'image'}: corner colors differ by {max_delta} "
            f"(tolerance {tolerance}); not writing a transparent version",
            file=sys.stderr,
        )
        return None
    return average


def _background_mask(img: Image.Image, background: tuple[int, int, int], tolerance: int) -> Image.Image:
    """Binary mask: 255 where the connected corner background reaches, 0 elsewhere.

    Pillow 12 removed ImageDraw.floodfill, so the connected component is
    walked with an explicit BFS. `subject` is 0 on background-like pixels and
    255 on subject-like pixels; the BFS marks the connected corner background
    in a separate all-zero mask, leaving subject-like pixels at 0.
    """
    rgb = img.convert("RGB")
    diff = ImageChops.difference(rgb, Image.new("RGB", rgb.size, background))
    r, g, b = diff.split()
    # A pixel is background only when every channel is within tolerance, so
    # the threshold uses the max channel delta rather than a luminance blend.
    subject = ImageChops.lighter(
        ImageChops.lighter(
            r.point(lambda p: 255 if p > tolerance else 0),
            g.point(lambda p: 255 if p > tolerance else 0),
        ),
        b.point(lambda p: 255 if p > tolerance else 0),
    )
    w, h = subject.size
    subject_data = subject.tobytes()
    background_data = bytearray(w * h)
    for x, y in _corners(rgb.size):
        start = y * w + x
        if subject_data[start] != 0:
            continue
        background_data[start] = 255
        queue = deque([start])
        while queue:
            idx = queue.popleft()
            cx = idx % w
            if cx > 0:
                left = idx - 1
                if subject_data[left] == 0 and background_data[left] == 0:
                    background_data[left] = 255
                    queue.append(left)
            if cx + 1 < w:
                right = idx + 1
                if subject_data[right] == 0 and background_data[right] == 0:
                    background_data[right] = 255
                    queue.append(right)
            if idx >= w:
                up = idx - w
                if subject_data[up] == 0 and background_data[up] == 0:
                    background_data[up] = 255
                    queue.append(up)
            if idx + w < w * h:
                down = idx + w
                if subject_data[down] == 0 and background_data[down] == 0:
                    background_data[down] = 255
                    queue.append(down)
    return Image.frombytes("L", subject.size, bytes(background_data))


def strip_background(
    src: str,
    out: str | None = None,
    tolerance: int = DEFAULT_TOLERANCE,
) -> str | None:
    """Write a transparent version of src; returns the output path or None if skipped."""
    if not os.path.isfile(src):
        raise FileNotFoundError(f"image not found: {src}")
    with Image.open(src) as img:
        background = _background_color(img, tolerance)
        if background is None:
            return None
        mask = _background_mask(img, background, tolerance)
        rgba = img.convert("RGBA")
        rgba.putalpha(mask.point(lambda p: 255 - p))
        if out is None:
            root, _ext = os.path.splitext(src)
            out = root + "_transparent.png"
        if os.path.normcase(os.path.abspath(out)) == os.path.normcase(os.path.abspath(src)):
            raise ValueError("refusing to overwrite the opaque original; choose a different --out")
        rgba.save(out, format="PNG")
    return out


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("image", help="source image (opaque original is left untouched)")
    parser.add_argument("--out", default=None, help="output PNG (default: <name>_transparent.png)")
    parser.add_argument(
        "--tolerance",
        type=int,
        default=DEFAULT_TOLERANCE,
        help=f"max per-channel color difference (default {DEFAULT_TOLERANCE})",
    )
    args = parser.parse_args(argv)
    if args.tolerance < 0:
        parser.error("--tolerance must be >= 0")
    try:
        out = strip_background(args.image, args.out, args.tolerance)
    except Exception as exc:  # noqa: BLE001 - CLI boundary, report and exit
        print(f"FAIL {args.image}: {exc}", file=sys.stderr)
        return 2
    if out is None:
        return 2
    print(f"wrote: {out}")
    return 0


if __name__ == "__main__":
    sys.exit(main())

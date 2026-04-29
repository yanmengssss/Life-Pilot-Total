#!/usr/bin/env python3
"""
Batch-unify image width by center-padding with white borders.

No scaling is applied to source images. By default, only width is unified and
each image keeps its original height. You can optionally force a unified
height via --target-height.
"""

from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image


SUPPORTED_EXTS = {".jpg", ".jpeg", ".png", ".bmp", ".tif", ".tiff", ".webp"}


def collect_images(folder: Path) -> list[Path]:
    return sorted(
        p for p in folder.iterdir() if p.is_file() and p.suffix.lower() in SUPPORTED_EXTS
    )


def parse_rgb(rgb_text: str) -> tuple[int, int, int]:
    parts = [x.strip() for x in rgb_text.split(",")]
    if len(parts) != 3:
        raise ValueError("RGB format must be like: 255,255,255")
    values = tuple(int(x) for x in parts)
    if any(v < 0 or v > 255 for v in values):
        raise ValueError("Each RGB value must be in 0..255")
    return values


def pad_to_canvas(
    src_path: Path,
    dst_path: Path,
    target_w: int,
    target_h: int | None,
    fill_color: tuple[int, int, int],
) -> tuple[int, int]:
    with Image.open(src_path) as src:
        src = src.convert("RGBA")
        sw, sh = src.size
        out_h = sh if target_h is None else target_h

        if sw > target_w or sh > out_h:
            raise ValueError(
                f"{src_path.name}: source size {sw}x{sh} exceeds target {target_w}x{out_h}"
            )

        canvas = Image.new("RGB", (target_w, out_h), fill_color)
        x = (target_w - sw) // 2
        y = (out_h - sh) // 2
        canvas.paste(src, (x, y), src)
        canvas.save(dst_path)
        return target_w, out_h


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Unify image width by center-padding (no scaling)."
    )
    parser.add_argument("input_dir", type=Path, help="Input image folder")
    parser.add_argument(
        "-o",
        "--output-dir",
        type=Path,
        default=None,
        help="Output folder (default: <input_dir>/padded)",
    )
    parser.add_argument(
        "--target-width",
        type=int,
        default=700,
        help="Target canvas width in pixels. Default: 700",
    )
    parser.add_argument(
        "--fill",
        type=str,
        default="255,255,255",
        help="Padding color in R,G,B format, e.g. 255,255,255",
    )

    args = parser.parse_args()
    input_dir = args.input_dir
    if not input_dir.exists() or not input_dir.is_dir():
        raise FileNotFoundError(f"Input directory does not exist: {input_dir}")

    images = collect_images(input_dir)
    if not images:
        raise RuntimeError(f"No supported images found in: {input_dir}")

    target_w = args.target_width
    target_h = None
    if target_w <= 0:
        raise ValueError("Target width must be a positive integer")

    fill_color = parse_rgb(args.fill)
    output_dir = args.output_dir or (input_dir / "padded")
    output_dir.mkdir(parents=True, exist_ok=True)

    ok_count = 0
    skip_count = 0
    skip_messages: list[str] = []
    min_h: int | None = None
    max_h: int | None = None
    for img_path in images:
        out_path = output_dir / img_path.name
        try:
            _, out_h = pad_to_canvas(
                src_path=img_path,
                dst_path=out_path,
                target_w=target_w,
                target_h=target_h,
                fill_color=fill_color,
            )
            min_h = out_h if min_h is None else min(min_h, out_h)
            max_h = out_h if max_h is None else max(max_h, out_h)
            ok_count += 1
        except Exception as exc:
            skip_count += 1
            skip_messages.append(f"{img_path.name}: {exc}")

    if ok_count > 0:
        print(
            f"Done. {ok_count} images saved to: {output_dir} | "
            f"target width: {target_w}px | heights kept (range: {min_h}-{max_h}px)"
        )
    else:
        print(f"Done. 0 images exported | target width: {target_w}px")

    if skip_count > 0:
        print(f"Skipped: {skip_count} image(s)")
        for msg in skip_messages:
            print(f"  - {msg}")


if __name__ == "__main__":
    main()

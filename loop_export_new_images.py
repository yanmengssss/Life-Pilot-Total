#!/usr/bin/env python3
"""
Continuously process images from source folder to target folder.

Rule:
- No scaling
- Unify width only
- Keep original height
- Center original image on target canvas
- Fill empty area with white
"""

from __future__ import annotations

import argparse
import time
from pathlib import Path

from PIL import Image


SUPPORTED_EXTS = {".jpg", ".jpeg", ".png", ".bmp", ".tif", ".tiff", ".webp"}


def list_images(folder: Path) -> list[Path]:
    return sorted(
        p for p in folder.iterdir() if p.is_file() and p.suffix.lower() in SUPPORTED_EXTS
    )


def infer_target_width(images: list[Path], fixed_width: int | None) -> int:
    if fixed_width is not None:
        return fixed_width
    max_w = 0
    for path in images:
        with Image.open(path) as im:
            max_w = max(max_w, im.size[0])
    return max_w


def pad_center_width_only(
    src: Path, dst: Path, target_w: int, fill: tuple[int, int, int] = (255, 255, 255)
) -> None:
    with Image.open(src) as im:
        im = im.convert("RGBA")
        w, h = im.size
        if w > target_w:
            raise ValueError(f"{src.name}: width {w} exceeds target width {target_w}")

        canvas = Image.new("RGB", (target_w, h), fill)
        x = (target_w - w) // 2
        canvas.paste(im, (x, 0), im)
        canvas.save(dst)


def process_once(src_dir: Path, dst_dir: Path, overwrite: bool, target_w: int) -> tuple[int, int]:
    images = list_images(src_dir)
    if not images:
        return 0, 0

    count = 0
    skip_count = 0
    for src in images:
        dst = dst_dir / src.name
        if dst.exists() and not overwrite:
            continue
        try:
            pad_center_width_only(src, dst, target_w)
            count += 1
        except Exception as exc:
            skip_count += 1
            print(f"[skip] {src.name}: {exc}")
    return count, skip_count


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Loop process images with centered white padding (width-only)."
    )
    parser.add_argument("--src", type=Path, default=Path("新图"), help="Source folder")
    parser.add_argument("--dst", type=Path, default=Path("新图二"), help="Target folder")
    parser.add_argument(
        "--target-width",
        type=int,
        default=1800,
        help="Target width in pixels. Default: 700",
    )
    parser.add_argument(
        "--watch",
        action="store_true",
        help="Keep looping and process newly added images",
    )
    parser.add_argument(
        "--interval",
        type=float,
        default=3.0,
        help="Loop interval in seconds when --watch is enabled",
    )
    parser.add_argument(
        "--overwrite",
        action="store_true",
        help="Overwrite existing files in target folder",
    )
    args = parser.parse_args()

    if args.target_width <= 0:
        raise ValueError("target-width must be a positive integer")

    src_dir = args.src
    dst_dir = args.dst
    if not src_dir.exists() or not src_dir.is_dir():
        raise FileNotFoundError(f"Source folder not found: {src_dir}")
    dst_dir.mkdir(parents=True, exist_ok=True)

    images = list_images(src_dir)
    target_w = infer_target_width(images, args.target_width)

    if not args.watch:
        n, s = process_once(src_dir, dst_dir, args.overwrite, target_w)
        print(
            f"Done: {n} image(s) exported to {dst_dir} | "
            f"target width: {target_w}px | skipped: {s}"
        )
        return

    print(
        f"Watching {src_dir} -> {dst_dir}, target width={target_w}px, "
        f"interval={args.interval}s, overwrite={args.overwrite}"
    )
    while True:
        try:
            n, s = process_once(src_dir, dst_dir, args.overwrite, target_w)
            if n > 0:
                print(
                    f"[{time.strftime('%H:%M:%S')}] exported {n} image(s), skipped {s}"
                )
            time.sleep(args.interval)
        except KeyboardInterrupt:
            print("\nStopped.")
            break
        except Exception as exc:
            print(f"[{time.strftime('%H:%M:%S')}] error: {exc}")
            time.sleep(args.interval)


if __name__ == "__main__":
    main()

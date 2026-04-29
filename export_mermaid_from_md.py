#!/usr/bin/env python3
from __future__ import annotations

import argparse
import re
import subprocess
import sys
from pathlib import Path


def read_text_auto(path: Path) -> str:
    for enc in ("utf-8", "utf-8-sig", "gb18030"):
        try:
            return path.read_text(encoding=enc)
        except UnicodeDecodeError:
            continue
    raise UnicodeDecodeError("unknown", b"", 0, 1, f"cannot decode: {path}")


def safe_name(name: str) -> str:
    name = name.strip()
    if not name:
        return "chart"
    name = re.sub(r"\s+", "_", name)
    name = re.sub(r'[\\/:*?"<>|]+', "_", name)
    name = re.sub(r"_+", "_", name).strip("_")
    return name or "chart"


def extract_mermaid_blocks(md_text: str) -> list[tuple[str, str]]:
    pattern = re.compile(r"```mermaid\s*\n(.*?)\n```", re.DOTALL | re.IGNORECASE)
    matches = list(pattern.finditer(md_text))
    if not matches:
        return []

    lines = md_text.splitlines()
    line_starts: list[int] = []
    pos = 0
    for line in lines:
        line_starts.append(pos)
        pos += len(line) + 1

    def find_heading(before_pos: int) -> str:
        idx = 0
        for i, st in enumerate(line_starts):
            if st <= before_pos:
                idx = i
            else:
                break
        for j in range(idx, -1, -1):
            text = lines[j].strip()
            if text.startswith("### "):
                return text[4:].strip()
            if text.startswith("## "):
                return text[3:].strip()
        return ""

    blocks: list[tuple[str, str]] = []
    for i, m in enumerate(matches, start=1):
        title = find_heading(m.start())
        name = safe_name(title) if title else f"chart{i:02d}"
        blocks.append((name, m.group(1).strip() + "\n"))
    return blocks


def run_mmdc(mmdc_cmd: str, in_file: Path, out_file: Path, width: int) -> None:
    cmd = [mmdc_cmd, "-i", str(in_file), "-o", str(out_file), "-w", str(width)]
    subprocess.run(cmd, check=True)


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Batch export Mermaid blocks from a Markdown file with mmdc."
    )
    parser.add_argument(
        "-m", "--markdown", type=Path, default=Path("图汇总.md"), help="Markdown file path"
    )
    parser.add_argument(
        "-o", "--output-dir", type=Path, default=Path("新图2"), help="PNG output directory"
    )
    parser.add_argument(
        "-w", "--width", type=int, default=800, help="Output width for mmdc (default: 800)"
    )
    parser.add_argument(
        "--mmdc", type=str, default="mmdc", help="mmdc command name or full path"
    )
    parser.add_argument(
        "--temp-dir",
        type=Path,
        default=None,
        help="Directory for temporary .mmd files (default: <output-dir>/.mmd_tmp)",
    )
    parser.add_argument(
        "--keep-mmd",
        action="store_true",
        help="Keep generated temporary .mmd files",
    )
    args = parser.parse_args()

    if args.width <= 0:
        print("width must be > 0", file=sys.stderr)
        return 2
    if not args.markdown.exists():
        print(f"markdown file not found: {args.markdown}", file=sys.stderr)
        return 2

    md_text = read_text_auto(args.markdown)
    blocks = extract_mermaid_blocks(md_text)
    if not blocks:
        print("no mermaid blocks found")
        return 1

    out_dir = args.output_dir
    out_dir.mkdir(parents=True, exist_ok=True)
    tmp_dir = args.temp_dir if args.temp_dir else (out_dir / ".mmd_tmp")
    tmp_dir.mkdir(parents=True, exist_ok=True)

    exported = 0
    for idx, (base_name, mermaid_code) in enumerate(blocks, start=1):
        mmd_path = tmp_dir / f"{idx:02d}_{base_name}.mmd"
        png_path = out_dir / f"{idx:02d}_{base_name}.png"
        mmd_path.write_text(mermaid_code, encoding="utf-8")
        try:
            run_mmdc(args.mmdc, mmd_path, png_path, args.width)
            exported += 1
            print(f"[ok] {png_path.name}")
        except subprocess.CalledProcessError as exc:
            print(f"[fail] {png_path.name}: {exc}", file=sys.stderr)
        except FileNotFoundError:
            print("mmdc command not found. Please install Mermaid CLI first.", file=sys.stderr)
            return 127

    if not args.keep_mmd:
        for f in tmp_dir.glob("*.mmd"):
            f.unlink(missing_ok=True)
        try:
            tmp_dir.rmdir()
        except OSError:
            pass

    print(f"done: {exported}/{len(blocks)} exported to {out_dir}")
    return 0 if exported == len(blocks) else 1


if __name__ == "__main__":
    raise SystemExit(main())

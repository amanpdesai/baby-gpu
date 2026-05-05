#!/usr/bin/env python3
"""Regenerate or verify checked-in UrbanaGPU kernel memory images."""

from __future__ import annotations

import argparse
import importlib.util
import sys
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[2]
ASM_PATH = REPO_ROOT / "tools" / "assembler" / "kgpu_asm.py"
KERNEL_DIR = REPO_ROOT / "tests" / "kernels"


def load_assembler():
    spec = importlib.util.spec_from_file_location("kgpu_asm", ASM_PATH)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"failed to load assembler from {ASM_PATH}")
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


def render_words(words: list[int]) -> str:
    return "".join(f"{word:08x}\n" for word in words)


def fixture_pairs() -> list[tuple[Path, Path]]:
    return [(source, source.with_suffix(".memh")) for source in sorted(KERNEL_DIR.glob("*.kgpu"))]


def orphan_memh_files() -> list[Path]:
    sources = {source.with_suffix(".memh") for source in KERNEL_DIR.glob("*.kgpu")}
    return [memh for memh in sorted(KERNEL_DIR.glob("*.memh")) if memh not in sources]


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--check", action="store_true", help="verify .memh fixtures match assembler output")
    mode.add_argument("--write", action="store_true", help="rewrite .memh fixtures from .kgpu sources")
    args = parser.parse_args(argv)

    check_only = not args.write
    asm = load_assembler()
    pairs = fixture_pairs()
    if not pairs:
        print(f"assemble_kernels: no .kgpu files found in {KERNEL_DIR}", file=sys.stderr)
        return 1

    failed = False
    orphans = orphan_memh_files()
    if orphans:
        for memh in orphans:
            print(
                f"assemble_kernels: orphan {memh.relative_to(REPO_ROOT)} has no matching .kgpu source",
                file=sys.stderr,
            )
        failed = True

    for source, memh in pairs:
        assembled = render_words(asm.assemble(source))
        rel_source = source.relative_to(REPO_ROOT)
        rel_memh = memh.relative_to(REPO_ROOT)

        if check_only:
            if not memh.exists():
                print(f"assemble_kernels: missing {rel_memh} for {rel_source}", file=sys.stderr)
                failed = True
                continue
            if memh.read_text() != assembled:
                print(f"assemble_kernels: stale {rel_memh}; run make assemble-kernels", file=sys.stderr)
                failed = True
        else:
            memh.write_text(assembled)
            print(f"WROTE {rel_memh}")

    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main())

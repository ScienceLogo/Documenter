"""Compiles the booklet with Typst."""

from __future__ import annotations

from pathlib import Path

import typst


def compile_booklet(source: Path, output: Path, font_dirs: list[Path]) -> None:
    """Compile `source` (booklet.typ) to the PDF `output`, using only the given fonts."""
    typst.compile(
        str(source),
        output=str(output),
        root=str(source.parent),
        font_paths=[str(d) for d in font_dirs],
        ignore_system_fonts=True,
    )

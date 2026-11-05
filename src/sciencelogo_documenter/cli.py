"""Command line entry point."""

from __future__ import annotations

import argparse
import sys
from collections.abc import Sequence

from sciencelogo_documenter import __version__


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="sciencelogo-documenter",
        description="Readable websites and PDF booklets from ScienceLogo workflows.",
    )
    parser.add_argument("--version", action="version", version=f"%(prog)s {__version__}")
    commands = parser.add_subparsers(dest="command", required=True)
    commands.add_parser("build", help="build the website and the booklet")
    commands.add_parser("publish", help="publish a built website")
    return parser


def main(argv: Sequence[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    print(f"{args.command}: not implemented yet", file=sys.stderr)
    return 2

"""Command line entry point."""

from __future__ import annotations

import argparse
import sys
from collections.abc import Sequence
from pathlib import Path

from sciencelogo_documenter import __version__


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="sciencelogo-documenter",
        description="Readable websites and PDF booklets from ScienceLogo workflows.",
    )
    parser.add_argument("--version", action="version", version=f"%(prog)s {__version__}")
    commands = parser.add_subparsers(dest="command", required=True)

    build = commands.add_parser("build", help="build the website and the booklet")
    build.add_argument("entry", type=Path, help="the workflow's entry file")
    build.add_argument("--out", type=Path, default=Path("documentation"),
                       help="output folder (default: documentation)")
    build.add_argument("--config", type=Path, help="settings file (default: sciencelogo-documenter.toml "
                       "at the root of the workflow repository, if present)")

    publish = commands.add_parser("publish", help="publish a built website")
    publish.add_argument("--target", required=True,
                         choices=["pages-branch", "github-pages", "gitlab-pages", "dir"])
    publish.add_argument("--site", type=Path, default=Path("documentation/site"),
                         help="the built website (default: documentation/site)")
    publish.add_argument("--branch", default="pages", help="branch for pages-branch (default: pages)")
    publish.add_argument("--remote", default="origin", help="remote for pages-branch (default: origin)")
    publish.add_argument("--folder", type=Path, help="destination folder for github-pages, gitlab-pages or dir")

    commands.add_parser("bootstrap", help=argparse.SUPPRESS)
    return parser


def main(argv: Sequence[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    try:
        if args.command == "build":
            from sciencelogo_documenter.build import build

            site = build(args.entry, args.out, args.config)
            print(f"Built {site}")
        elif args.command == "publish":
            from sciencelogo_documenter.publish import publish

            where = publish(args.target, args.site, branch=args.branch, folder=args.folder,
                            remote=args.remote)
            print(f"Published to {where}")
        elif args.command == "bootstrap":
            from sciencelogo_documenter.bootstrap import racket_bin

            print(racket_bin())
    except Exception as e:  # noqa: BLE001 - every failure ends with a readable message
        name = type(e).__name__
        if name in ("BuildError", "PublishError", "ConfigError", "BootstrapError"):
            print(f"error: {e}", file=sys.stderr)
            return 1
        raise
    return 0

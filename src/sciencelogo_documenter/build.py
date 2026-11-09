"""Builds the website and the booklet of one workflow."""

from __future__ import annotations

import json
import shutil
import subprocess
import sys
import tempfile
from importlib.resources import as_file, files
from pathlib import Path

from sciencelogo_documenter import bootstrap, config
from sciencelogo_documenter.booklet import compile_booklet


class BuildError(RuntimeError):
    pass


def settings_root(path: Path) -> Path:
    """The root of the Git repository that holds `path`, or `path` itself."""
    result = subprocess.run(
        ["git", "-C", str(path), "rev-parse", "--show-toplevel"],
        capture_output=True,
        text=True,
    )
    return Path(result.stdout.strip()) if result.returncode == 0 else path


def build(entry: Path, out: Path, config_path: Path | None = None) -> Path:
    """Build `out/site`, with the booklet inside it. Return the site folder.

    If the workflow is invalid, nothing is written and BuildError carries the
    reader's message.
    """
    entry = entry.resolve()
    if not entry.is_file():
        raise BuildError(f"{entry} does not exist")
    root = settings_root(entry.parent)
    if config_path is None and (root / config.CONFIG_NAME).is_file():
        config_path = root / config.CONFIG_NAME
    settings, warnings = config.load(config_path)
    for w in warnings:
        print(f"warning: {w}", file=sys.stderr)

    racket = bootstrap.racket_bin(settings["versions"]) / "racket"
    package = files("sciencelogo_documenter")
    with as_file(package) as package_dir, tempfile.TemporaryDirectory() as tmp:
        package_dir = Path(package_dir)
        tmp_path = Path(tmp)
        site = tmp_path / "site"
        work = tmp_path / "work"
        work.mkdir()

        # Files named in the settings are copied next to the outputs.
        faces = []
        for i, face in enumerate(settings["fonts"]["faces"]):
            name = f"{i}-{Path(face['file']).name}"
            faces.append({**face, "url": f"fonts/custom/{name}", "name": name})
        settings["fonts"]["faces"] = faces
        if settings["booklet"].get("logo"):
            logo = Path(settings["booklet"]["logo"])
            shutil.copyfile(logo, work / f"logo{logo.suffix}")
            settings["booklet"]["logo_file"] = f"logo{logo.suffix}"
        settings_file = tmp_path / "settings.json"
        settings_file.write_text(json.dumps(settings))

        result = subprocess.run(
            [str(racket), str(package_dir / "racket" / "main.rkt"), "build",
             str(entry), str(settings_file), str(site), str(work)],
            capture_output=True,
            text=True,
        )
        if result.returncode != 0:
            raise BuildError(result.stderr.strip() or "the build failed")
        if result.stderr.strip():
            print(result.stderr.strip(), file=sys.stderr)

        font_dirs = [package_dir / "fonts" / "atkinson-hyperlegible-next",
                     package_dir / "fonts" / "atkinson-hyperlegible-mono"]
        if faces:
            custom = site / "fonts" / "custom"
            custom.mkdir(parents=True, exist_ok=True)
            for face in faces:
                shutil.copyfile(face["file"], custom / face["name"])
            font_dirs.insert(0, custom)
        compile_booklet(work / "booklet.typ", site / "booklet.pdf", font_dirs)

        out.mkdir(parents=True, exist_ok=True)
        target = out / "site"
        if target.exists():
            shutil.rmtree(target)
        shutil.move(str(site), str(target))
    return target

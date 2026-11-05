"""Racket and the `sciencelogo` package, downloaded once and kept in a cache."""

from __future__ import annotations

import hashlib
import os
import platform
import shutil
import subprocess
import sys
import tarfile
import tempfile
import urllib.request
from pathlib import Path

from sciencelogo_documenter import versions


class BootstrapError(RuntimeError):
    pass


def cache_root() -> Path:
    """The folder that holds the Documenter's downloads."""
    explicit = os.environ.get("SCIENCELOGO_DOCUMENTER_CACHE")
    if explicit:
        return Path(explicit)
    base = os.environ.get("XDG_CACHE_HOME")
    return (Path(base) if base else Path.home() / ".cache") / "sciencelogo-documenter"


def platform_key() -> str:
    machine = platform.machine().lower()
    system = platform.system().lower()
    if machine in ("x86_64", "amd64") and system == "linux":
        return "x86_64-linux"
    raise BootstrapError(f"no pinned Racket build for {system} on {machine}")


def _versions(overrides: dict | None) -> dict:
    overrides = overrides or {}
    url, sha256 = (None, None)
    if overrides.get("racket_url"):
        url, sha256 = overrides["racket_url"], overrides.get("racket_sha256")
    else:
        url, sha256 = versions.racket_tarball(platform_key())
    return {
        "racket_url": url,
        "racket_sha256": sha256,
        "sciencelogo_url": overrides.get("sciencelogo_url") or versions.SCIENCELOGO_URL,
        "sciencelogo_checksum": overrides.get("sciencelogo_checksum") or versions.SCIENCELOGO_CHECKSUM,
    }


def _download(url: str, dest: Path) -> None:
    with urllib.request.urlopen(url, timeout=120) as response, open(dest, "wb") as out:
        shutil.copyfileobj(response, out)


def _sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            digest.update(chunk)
    return digest.hexdigest()


def racket_bin(overrides: dict | None = None) -> Path:
    """Return the `bin` folder of a Racket that has `sciencelogo` installed.

    The environment variable SCIENCELOGO_DOCUMENTER_RACKET can name the `bin`
    folder of an existing installation instead.
    """
    existing = os.environ.get("SCIENCELOGO_DOCUMENTER_RACKET")
    if existing:
        return Path(existing)

    chosen = _versions(overrides)
    key = hashlib.sha256(repr(sorted(chosen.items())).encode()).hexdigest()[:12]
    dest = cache_root() / f"racket-{key}"
    if (dest / ".complete").exists():
        return dest / "bin"

    print("Installing Racket and the sciencelogo package (first run only)...", file=sys.stderr)
    cache_root().mkdir(parents=True, exist_ok=True)
    if dest.exists():
        shutil.rmtree(dest)
    with tempfile.TemporaryDirectory(dir=cache_root()) as tmp:
        tmp_path = Path(tmp)
        tarball = tmp_path / "racket.tgz"
        _download(chosen["racket_url"], tarball)
        if chosen["racket_sha256"] and _sha256(tarball) != chosen["racket_sha256"]:
            raise BootstrapError("the Racket download does not match its pinned checksum")
        with tarfile.open(tarball) as archive:
            archive.extractall(tmp_path / "unpacked", filter="data")
        # Racket is installed in place, so it is moved before any package is added.
        (tmp_path / "unpacked" / "racket").rename(dest)
    result = subprocess.run(
        [
            str(dest / "bin" / "raco"), "pkg", "install", "--auto", "--batch", "--no-docs",
            "--scope", "installation",
            "--checksum", chosen["sciencelogo_checksum"],
            chosen["sciencelogo_url"],
        ],
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        raise BootstrapError("installing the sciencelogo package failed:\n" + result.stderr[-4000:])
    (dest / ".complete").write_text("ok\n")
    return dest / "bin"

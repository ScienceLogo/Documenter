"""Versions tested with this release of the Documenter."""

from __future__ import annotations

RACKET_VERSION = "9.3"
RACKET_MIRROR = f"https://mirror.racket-lang.org/installers/{RACKET_VERSION}/"

# Minimal Racket CS tarballs, by platform: file name and SHA-256.
RACKET_TARBALLS = {
    "x86_64-linux": (
        f"racket-minimal-{RACKET_VERSION}-x86_64-linux-buster-cs.tgz",
        "8f469b7e93645fc876594470d884775aafff7688f530fd38be873fb44c71ca6a",
    ),
}

# The `sciencelogo` Racket package, from a fixed release of the language,
# with the package checksum published for that release.
SCIENCELOGO_RELEASE = "v0.1"
SCIENCELOGO_URL = (
    "https://github.com/ScienceLogo/Language/releases/download/"
    f"{SCIENCELOGO_RELEASE}/sciencelogo.zip"
)
SCIENCELOGO_CHECKSUM = "04adaefe40a00014c21e600431f7adaef35bf707"


def racket_tarball(platform: str) -> tuple[str, str]:
    """Return the download URL and SHA-256 of the Racket tarball for a platform."""
    try:
        name, sha256 = RACKET_TARBALLS[platform]
    except KeyError:
        raise ValueError(f"no pinned Racket build for platform {platform!r}") from None
    return RACKET_MIRROR + name, sha256

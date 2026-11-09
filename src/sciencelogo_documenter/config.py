"""Settings: the standard style, overridden by an optional TOML file."""

from __future__ import annotations

import copy
import tomllib
from pathlib import Path

CONFIG_NAME = "sciencelogo-documenter.toml"

# The standard style. Colours of the categories are Okabe-Ito hues, used as
# markers next to a type style that carries the meaning on its own.
DEFAULTS: dict = {
    "title": None,
    "site": {"logo": None, "favicon": None},
    "layout": {"page_depth": 3},
    "booklet": {"paper": "a4", "body_size": "10.5pt", "logo": None},
    "fonts": {
        "text": "Atkinson Hyperlegible Next",
        "code": "Atkinson Hyperlegible Mono",
        "faces": [],
    },
    "colours": {
        "light": {
            "background": "#ffffff",
            "text": "#1a1a1a",
            "muted": "#555555",
            "link": "#1d4f91",
            "border": "#d0d0d0",
            "code_background": "#f4f4f4",
        },
        "dark": {
            "background": "#121212",
            "text": "#ececec",
            "muted": "#b0b0b0",
            "link": "#8ab4f8",
            "border": "#3a3a3a",
            "code_background": "#1e1e1e",
        },
        "categories": {
            "light": {"stage": "#0072B2", "performer": "#E69F00", "procedure": "#009E73", "uncertainty": "#D55E00"},
            "dark": {"stage": "#56B4E9", "performer": "#E69F00", "procedure": "#009E73", "uncertainty": "#D55E00"},
        },
    },
    "index": {"kinds": ["Phases", "Stages", "Procedures", "Performers", "Record types", "Requirements"]},
    "versions": {
        "racket_url": None,
        "racket_sha256": None,
        "sciencelogo_url": None,
        "sciencelogo_checksum": None,
    },
}


class ConfigError(ValueError):
    pass


def _merge(base: dict, override: dict, where: str, warnings: list[str]) -> dict:
    result = copy.deepcopy(base)
    for key, value in override.items():
        name = f"{where}.{key}" if where else key
        if key not in base:
            warnings.append(f"unknown setting {name!r} is ignored")
            continue
        if isinstance(base[key], dict) and isinstance(value, dict):
            result[key] = _merge(base[key], value, name, warnings)
        else:
            result[key] = value
    return result


def _luminance(colour: str) -> float:
    c = colour.lstrip("#")
    if len(c) == 3:
        c = "".join(ch * 2 for ch in c)
    channels = [int(c[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    linear = [ch / 12.92 if ch <= 0.03928 else ((ch + 0.055) / 1.055) ** 2.4 for ch in channels]
    return 0.2126 * linear[0] + 0.7152 * linear[1] + 0.0722 * linear[2]


def contrast(a: str, b: str) -> float:
    """WCAG contrast ratio of two colours written as #rrggbb."""
    la, lb = sorted((_luminance(a), _luminance(b)), reverse=True)
    return (la + 0.05) / (lb + 0.05)


def contrast_warnings(settings: dict) -> list[str]:
    warnings = []
    for mode in ("light", "dark"):
        palette = settings["colours"][mode]
        for key in ("text", "muted", "link"):
            try:
                ratio = contrast(palette[key], palette["background"])
            except (KeyError, ValueError):
                warnings.append(f"colours.{mode}.{key} is not a #rrggbb colour")
                continue
            if ratio < 4.5:
                warnings.append(
                    f"colours.{mode}.{key} has a contrast of {ratio:.1f}:1 with the background, below 4.5:1"
                )
    return warnings


def load(path: Path | None) -> tuple[dict, list[str]]:
    """Return the settings and any warnings. Paths in the file are resolved
    against the file's folder."""
    warnings: list[str] = []
    if path is None:
        settings = copy.deepcopy(DEFAULTS)
    else:
        try:
            with open(path, "rb") as f:
                data = tomllib.load(f)
        except OSError as e:
            raise ConfigError(f"cannot read {path}: {e}") from None
        except tomllib.TOMLDecodeError as e:
            raise ConfigError(f"{path} is not valid TOML: {e}") from None
        settings = _merge(DEFAULTS, data, "", warnings)
        base = path.parent
        for section, key in (("site", "logo"), ("site", "favicon"), ("booklet", "logo")):
            value = settings[section].get(key)
            if value:
                resolved = (base / value).resolve()
                if not resolved.is_file():
                    raise ConfigError(f"{section}.{key}: {value} does not exist")
                settings[section][key] = str(resolved)
        faces = []
        for face in settings["fonts"].get("faces") or []:
            if not isinstance(face, dict) or "family" not in face or "file" not in face:
                raise ConfigError("each fonts.faces entry needs a family and a file")
            resolved = (base / face["file"]).resolve()
            if not resolved.is_file():
                raise ConfigError(f"fonts.faces: {face['file']} does not exist")
            faces.append({**face, "file": str(resolved)})
        settings["fonts"]["faces"] = faces
    try:
        depth = int(settings["layout"]["page_depth"])
    except (TypeError, ValueError):
        raise ConfigError("layout.page_depth must be a number") from None
    settings["layout"]["page_depth"] = depth
    warnings.extend(contrast_warnings(settings))
    return settings, warnings

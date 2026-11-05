"""Publishes a built website: to a branch, a Pages folder or a plain folder.

Publishing never changes the workflow's files.
"""

from __future__ import annotations

import os
import shutil
import subprocess
import tempfile
from pathlib import Path
from urllib.parse import urlsplit, urlunsplit

TARGETS = ("pages-branch", "github-pages", "gitlab-pages", "dir")
DEFAULT_FOLDERS = {"github-pages": "_site", "gitlab-pages": "public"}


class PublishError(RuntimeError):
    pass


def _git(*args: str, cwd: Path | None = None, secret: str | None = None) -> str:
    result = subprocess.run(["git", *args], cwd=cwd, capture_output=True, text=True)
    if result.returncode != 0:
        message = (result.stderr or result.stdout).strip()
        if secret:
            message = message.replace(secret, "***")
        raise PublishError(message)
    return result.stdout.strip()


def _copy_site(site: Path, folder: Path) -> None:
    if folder.exists():
        shutil.rmtree(folder)
    shutil.copytree(site, folder)


def _token() -> str | None:
    for name in ("GITHUB_TOKEN", "FORGEJO_TOKEN", "GITEA_TOKEN"):
        if os.environ.get(name):
            return os.environ[name]
    return None


def _push_branch(site: Path, branch: str, remote: str, message: str) -> None:
    repo = Path(_git("rev-parse", "--show-toplevel"))
    url = _git("remote", "get-url", remote, cwd=repo)
    with tempfile.TemporaryDirectory() as tmp:
        work = Path(tmp) / "site"
        shutil.copytree(site, work)
        (work / ".nojekyll").write_text("")
        _git("init", "-q", cwd=work)
        _git("checkout", "-q", "-b", branch, cwd=work)

        # The CI job's own credentials: the header that the checkout step
        # stored, or a token from the environment.
        headers = subprocess.run(
            ["git", "config", "--get-regexp", r"^http\..*\.extraheader$"],
            cwd=repo, capture_output=True, text=True,
        ).stdout.splitlines()
        for line in headers:
            key, _, value = line.partition(" ")
            _git("config", key, value, cwd=work)
        secret = None
        push_url = url
        token = _token()
        if not headers and token and url.startswith("https://"):
            parts = urlsplit(url)
            user = os.environ.get("GITHUB_ACTOR") or "token"
            push_url = urlunsplit(parts._replace(netloc=f"{user}:{token}@{parts.hostname}"))
            secret = token

        name = _config_value(repo, "user.name") or os.environ.get("GITHUB_ACTOR") or os.environ.get("GITLAB_USER_LOGIN")
        email = _config_value(repo, "user.email") or (f"{name}@users.noreply.github.com" if name else None)
        _git("config", "user.name", name or "publish", cwd=work)
        _git("config", "user.email", email or "publish@localhost", cwd=work)
        _git("add", "-A", cwd=work)
        _git("commit", "-q", "-m", message, cwd=work)
        _git("push", "-q", "--force", push_url, f"HEAD:refs/heads/{branch}", cwd=work, secret=secret)


def _config_value(repo: Path, key: str) -> str | None:
    result = subprocess.run(["git", "config", "--get", key], cwd=repo, capture_output=True, text=True)
    return result.stdout.strip() or None


def publish(target: str, site: Path, *, branch: str = "pages", folder: Path | None = None,
            remote: str = "origin", message: str | None = None) -> str:
    """Publish `site` to `target` and return a short description of where it went."""
    if target not in TARGETS:
        raise PublishError(f"unknown target {target!r}; choose one of {', '.join(TARGETS)}")
    if not (site / "index.html").is_file():
        raise PublishError(f"{site} is not a built website; run build first")
    if target == "pages-branch":
        sha = os.environ.get("GITHUB_SHA") or os.environ.get("CI_COMMIT_SHA")
        _push_branch(site, branch, remote, message or ("Publish documentation" + (f" for {sha[:8]}" if sha else "")))
        return f"branch {branch} of {remote}"
    if target == "dir" and folder is None:
        raise PublishError("the dir target needs --folder")
    folder = folder or Path(DEFAULT_FOLDERS[target])
    _copy_site(site, folder)
    if target == "github-pages":
        (folder / ".nojekyll").write_text("")
    return str(folder)

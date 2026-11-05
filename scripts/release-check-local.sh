#!/usr/bin/env bash
# Build the wheel and the sdist, check them, install the wheel in a fresh
# virtual environment and run the tests against the installed package.
set -eu

PYTHON="${PYTHON:-python}"
ROOT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
WORK_DIR="$(mktemp -d)"
cleanup() {
  rm -rf "$WORK_DIR"
}
trap cleanup EXIT

DIST_DIR="$WORK_DIR/dist"
TOOLS_DIR="$WORK_DIR/tools"
VENV_DIR="$WORK_DIR/venv"

"$PYTHON" -m venv "$TOOLS_DIR"
"$TOOLS_DIR/bin/python" -m pip install --quiet build twine
"$TOOLS_DIR/bin/python" -m build --outdir "$DIST_DIR" "$ROOT_DIR" >/dev/null
"$TOOLS_DIR/bin/python" -m twine check --strict "$DIST_DIR"/*

if ! tar -tzf "$DIST_DIR"/*.tar.gz | grep -q "/src/sciencelogo_documenter/racket/main.rkt$"; then
  echo "the sdist does not contain the Racket entry point" >&2
  exit 1
fi

"$PYTHON" -m venv "$VENV_DIR"
"$VENV_DIR/bin/python" -m pip install --quiet --no-deps "$DIST_DIR"/*.whl
"$VENV_DIR/bin/sciencelogo-documenter" --version

cd "$WORK_DIR"
env -u PYTHONPATH "$VENV_DIR/bin/python" -m unittest discover -s "$ROOT_DIR/tests/python"

ls "$DIST_DIR"

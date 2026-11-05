#!/usr/bin/env bash
# Build the wheel and the sdist, check them, install the wheel in a fresh
# virtual environment, run the tests against it and build the example.
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

for f in racket/main.rkt static/template.typ fonts/atkinson-hyperlegible-next/OFL.txt; do
  if ! tar -tzf "$DIST_DIR"/*.tar.gz | grep -q "/src/sciencelogo_documenter/$f$"; then
    echo "the sdist does not contain $f" >&2
    exit 1
  fi
done

"$PYTHON" -m venv "$VENV_DIR"
"$VENV_DIR/bin/python" -m pip install --quiet "$DIST_DIR"/*.whl
"$VENV_DIR/bin/sciencelogo-documenter" --version

cd "$WORK_DIR"
env -u PYTHONPATH "$VENV_DIR/bin/python" -m unittest discover -s "$ROOT_DIR/tests/python"
if [ -n "${SCIENCELOGO_DOCUMENTER_RACKET:-}" ]; then
  "$VENV_DIR/bin/sciencelogo-documenter" build "$ROOT_DIR/examples/pendulum/workflow.rkt" --out "$WORK_DIR/example"
  test -f "$WORK_DIR/example/site/booklet.pdf"
fi

ls "$DIST_DIR"

#!/usr/bin/env bash
set -eu

PYTHON="${PYTHON:-python}"
RACO="${RACO:-raco}"
cd "$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"

export PYTHONPATH="${PYTHONPATH:+$PYTHONPATH:}src"

"$PYTHON" -m compileall -q src tests
"$PYTHON" -m unittest discover -s tests/python -v
"$RACO" test tests/racket
"$PYTHON" -m sciencelogo_documenter --version >/dev/null

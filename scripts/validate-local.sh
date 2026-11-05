#!/usr/bin/env bash
# Unit and end-to-end tests. Racket comes from SCIENCELOGO_DOCUMENTER_RACKET
# (a `bin` folder), or from the Documenter's own pinned installation.
set -eu

PYTHON="${PYTHON:-python}"
cd "$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"

export PYTHONPATH="${PYTHONPATH:+$PYTHONPATH:}src"
if [ -z "${SCIENCELOGO_DOCUMENTER_RACKET:-}" ]; then
  SCIENCELOGO_DOCUMENTER_RACKET="$("$PYTHON" -m sciencelogo_documenter bootstrap)"
fi
export SCIENCELOGO_DOCUMENTER_RACKET

"$PYTHON" -m compileall -q src tests
"$PYTHON" -m unittest discover -s tests/python -v
"$SCIENCELOGO_DOCUMENTER_RACKET/raco" test tests/racket
"$PYTHON" -m sciencelogo_documenter --version >/dev/null

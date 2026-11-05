#!/usr/bin/env bash
# Install the pinned minimal Racket into a folder, plus rackunit for the tests.
set -eu

DEST="${1:?usage: install-racket.sh <folder>}"
PYTHON="${PYTHON:-python}"
ROOT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
WORK_DIR="$(mktemp -d)"
cleanup() {
  rm -rf "$WORK_DIR"
}
trap cleanup EXIT

read -r URL SHA256 < <(PYTHONPATH="$ROOT_DIR/src" "$PYTHON" -m sciencelogo_documenter.versions x86_64-linux)

curl -fsSL "$URL" -o "$WORK_DIR/racket.tgz"
echo "$SHA256  $WORK_DIR/racket.tgz" | sha256sum -c -

mkdir -p "$DEST"
tar -xzf "$WORK_DIR/racket.tgz" -C "$DEST" --strip-components=1
"$DEST/bin/raco" pkg install --auto --no-docs --scope installation rackunit-lib

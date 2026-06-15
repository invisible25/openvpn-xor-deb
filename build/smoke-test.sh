#!/bin/bash
# Прогон smoke-теста overlay в чистом контейнере. Аргументы: <DEB> <OVPN>
set -euo pipefail
DEB="$1"; OVPN="$2"
BASE="$(cd "$(dirname "$0")" && pwd)"
exec docker run --rm \
  -v "$BASE":/work -w /work \
  "debian:${DEB}" \
  bash /work/smoke-inner.sh "$DEB" "$OVPN"

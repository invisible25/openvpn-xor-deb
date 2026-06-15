#!/bin/bash
# Запуск сборки одной ячейки в контейнере debian:<DEB>. Аргументы: <DEB> <OVPN>
set -euo pipefail
DEB="$1"; OVPN="$2"
BASE="$(cd "$(dirname "$0")" && pwd)"
exec docker run --rm \
  -v "$BASE":/work -w /work \
  "debian:${DEB}" \
  bash /work/inner.sh "$DEB" "$OVPN"

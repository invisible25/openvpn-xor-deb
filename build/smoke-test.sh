#!/bin/bash
# Установка собранного пакета поверх штатного openvpn в чистом контейнере
# целевой системы и откат. Аргументы: <ЦЕЛЬ> <OVPN> (как у build-one.sh).
set -euo pipefail
TARGET="$1"; OVPN="$2"
BASE="$(cd "$(dirname "$0")" && pwd)"
case "$TARGET" in
  ubuntu*) IMAGE="ubuntu:${TARGET#ubuntu}"; TAG="$TARGET" ;;
  *)       IMAGE="debian:${TARGET}";       TAG="deb${TARGET}" ;;
esac
exec docker run --rm \
  -v "$BASE":/work -w /work \
  "$IMAGE" \
  bash /work/smoke-inner.sh "$TAG" "$OVPN"

#!/bin/bash
# Сборка одной ячейки в чистом контейнере целевой системы.
# Аргументы: <ЦЕЛЬ> <OVPN>; ЦЕЛЬ — 12 / 13 (Debian) или ubuntu22.04 / ubuntu24.04 / ubuntu26.04.
# Пакет собирается в контейнере той же системы, куда будет ставиться: только
# так dpkg-shlibdeps выводит точные зависимости (libssl3 против libssl3t64,
# версия glibc) — пакет Debian 12 на Ubuntu 22.04 не встал бы из-за glibc 2.36.
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
  bash /work/inner.sh "$TAG" "$OVPN"

#!/bin/bash
# Скачать официальные тарболы OpenVPN и проверить их подлинность.
#
# Патчи XOR в сеть не ходят — они лежат в build/patches/<версия>/ в самом
# репозитории. Версии и контрольные суммы — в build/sources.lock.
#
# Проверка двухступенчатая и обязательная:
#   1. SHA-256 из sources.lock — ловит подмену и порчу до распаковки;
#   2. подпись OpenVPN (.asc) ключом, закреплённым по отпечатку, — подтверждает,
#      что архив выпустил именно OpenVPN, а не тот, кто подменил и тарбол,
#      и его сумму в зеркале.
# Любое несовпадение — остановка. Собирать неподтверждённый код openvpn,
# который потом встанет на все ноды, нельзя.
set -euo pipefail

BASE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=sources.lock
. "$BASE/sources.lock"

OVPNS="${OVPNS_OVERRIDE:-$OVPNS}"
RELEASES="https://github.com/OpenVPN/openvpn/releases/download"

need() { command -v "$1" >/dev/null 2>&1 || { echo "нужна утилита: $1" >&2; exit 1; }; }
need curl
need sha256sum
need gpg

mkdir -p "$BASE/src"

# Отдельный keyring: ни системный, ни пользовательский ключи не должны
# влиять на решение о доверии.
GNUPGHOME="$(mktemp -d)"
export GNUPGHOME
trap 'rm -rf "$GNUPGHOME"' EXIT
gpg --quiet --batch --import "$BASE/keys/openvpn-security.asc" 2>/dev/null

# Импортированный ключ обязан быть ровно тем, что закреплён в sources.lock:
# иначе подменённый файл ключа сделал бы любую подпись «верной».
if ! gpg --batch --with-colons --fingerprint "$OPENVPN_SIGNING_KEY" 2>/dev/null \
     | grep -q "^fpr:::::::::${OPENVPN_SIGNING_KEY}:"; then
  echo "!!! ключ в keys/openvpn-security.asc не совпадает с OPENVPN_SIGNING_KEY" >&2
  exit 2
fi

for v in $OVPNS; do
  echo "== openvpn-$v =="
  tar_path="$BASE/src/openvpn-$v.tar.gz"
  asc_path="$tar_path.asc"

  var="SHA256_${v//./_}"
  expected="${!var:-}"
  if [ -z "$expected" ]; then
    echo "!!! в sources.lock нет $var — сначала update-sources.sh" >&2
    exit 2
  fi

  if [ ! -f "$tar_path" ] || ! echo "$expected  $tar_path" | sha256sum -c --status 2>/dev/null; then
    curl -fsSL --retry 3 -o "$tar_path" "$RELEASES/v$v/openvpn-$v.tar.gz"
  fi
  curl -fsSL --retry 3 -o "$asc_path" "$RELEASES/v$v/openvpn-$v.tar.gz.asc"

  if ! echo "$expected  $tar_path" | sha256sum -c --status; then
    echo "!!! SHA-256 openvpn-$v.tar.gz не совпадает с sources.lock" >&2
    echo "    ожидалось: $expected" >&2
    echo "    получено:  $(sha256sum "$tar_path" | cut -d' ' -f1)" >&2
    rm -f "$tar_path"
    exit 2
  fi
  echo "   SHA-256: совпадает"

  # VALIDSIG печатает отпечаток ОСНОВНОГО ключа последним полем — сверяем именно
  # его, а не подключ: подключи OpenVPN ротирует.
  status="$(gpg --batch --status-fd 1 --verify "$asc_path" "$tar_path" 2>/dev/null || true)"
  primary="$(echo "$status" | awk '/^\[GNUPG:\] VALIDSIG/ {print $NF}')"
  if [ "$primary" != "$OPENVPN_SIGNING_KEY" ]; then
    echo "!!! подпись openvpn-$v.tar.gz не подтверждена ключом OpenVPN" >&2
    echo "$status" | grep -E "BADSIG|ERRSIG|EXPKEYSIG|REVKEYSIG|NO_PUBKEY" >&2 || true
    exit 2
  fi
  echo "   подпись: OpenVPN Security Mailing List"

  patches="$BASE/patches/$v"
  count="$(find "$patches" -name '0[2-6]-*.diff' 2>/dev/null | wc -l)"
  if [ "$count" -ne 5 ]; then
    echo "!!! в $patches ожидается 5 XOR-патчей (02..06), найдено $count" >&2
    exit 2
  fi
  echo "   XOR-патчи: 5 из репозитория"
done

echo "== исходники подтверждены =="
du -h "$BASE"/src/*.tar.gz

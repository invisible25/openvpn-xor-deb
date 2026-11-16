#!/bin/bash
# Обновление источников до последних версий веток, которые поддерживает Tunnelblick.
#
# Что делает:
#   1. смотрит, какие версии сейчас лежат в Tunnelblick (third_party/sources/openvpn);
#   2. для каждой подписанной версии забирает XOR-патчи 02..06 из того коммита,
#      которым она была добавлена, и кладёт их в build/patches/<версия>/;
#   3. записывает в sources.lock версии, SHA-256 официальных тарболов и коммиты.
# Ключ подписи обновляется с keys.openpgp.org по закреплённому отпечатку.
#
# Git-снапшоты Tunnelblick (вида 2.5_git_37160ee) пропускаются: у них нет
# подписи OpenVPN, и '_' недопустим в версии deb-пакета.
#
# После запуска — посмотреть git diff и собрать: bash build/build-all.sh
set -euo pipefail
BASE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=sources.lock
. "$BASE/sources.lock"

API="https://api.github.com/repos/Tunnelblick/Tunnelblick"
TREE="third_party/sources/openvpn"
AUTH=()
[ -n "${GITHUB_TOKEN:-}" ] && AUTH=(-H "Authorization: Bearer $GITHUB_TOKEN")

api() { curl -fsSL "${AUTH[@]}" -H "Accept: application/vnd.github+json" "$API/$1"; }
need() { command -v "$1" >/dev/null 2>&1 || { echo "нужна утилита: $1" >&2; exit 1; }; }
need curl; need jq; need sha256sum; need gpg

# Сохраняем ветку 2.5, даже если Tunnelblick держит в ней только git-снапшот:
# последний подписанный релиз ветки берётся из уже записанного в lock.
declare -A LATEST=()
for old in $OVPNS; do LATEST["${old%.*}"]="$old"; done

for name in $(api "contents/$TREE" | jq -r '.[] | select(.type=="dir") | .name'); do
  ver="${name#openvpn-}"
  if [[ ! "$ver" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "пропуск $name: не подписанный релиз"
    continue
  fi
  LATEST["${ver%.*}"]="$ver"
done

NEW_OVPNS=""
LOCK_LINES=""
for branch in $(printf '%s\n' "${!LATEST[@]}" | sort -V); do
  v="${LATEST[$branch]}"
  NEW_OVPNS="$NEW_OVPNS $v"
  key="${v//./_}"

  commit="$(api "commits?path=$TREE/openvpn-$v&per_page=1" | jq -r '.[0].sha')"
  # Если версия уже удалена из main, нужен коммит ДО удаления — его родитель.
  if ! api "contents/$TREE/openvpn-$v?ref=$commit" >/dev/null 2>&1; then
    commit="$(api "commits/$commit" | jq -r '.parents[0].sha')"
  fi
  echo "== $v (патчи из ${commit:0:12}) =="

  mkdir -p "$BASE/patches/$v"
  for p in 02-tunnelblick-openvpn_xorpatch-a.diff 03-tunnelblick-openvpn_xorpatch-b.diff \
           04-tunnelblick-openvpn_xorpatch-c.diff 05-tunnelblick-openvpn_xorpatch-d.diff \
           06-tunnelblick-openvpn_xorpatch-e.diff; do
    api "contents/$TREE/openvpn-$v/patches/$p?ref=$commit" | jq -r '.content' | base64 -d \
      > "$BASE/patches/$v/$p"
  done

  tmp="$(mktemp)"
  curl -fsSL --retry 3 -o "$tmp" \
    "https://github.com/OpenVPN/openvpn/releases/download/v$v/openvpn-$v.tar.gz"
  sha="$(sha256sum "$tmp" | cut -d' ' -f1)"
  rm -f "$tmp"

  LOCK_LINES="${LOCK_LINES}SHA256_${key}=\"${sha}\"\nPATCHES_FROM_${key}=\"${commit}\"\n"
done

curl -fsSL "https://keys.openpgp.org/vks/v1/by-fingerprint/$OPENVPN_SIGNING_KEY" \
  -o "$BASE/keys/openvpn-security.asc"

{
  sed -n '1,/^OPENVPN_SIGNING_KEY=/p' "$BASE/sources.lock"
  echo
  echo "OVPNS=\"${NEW_OVPNS# }\""
  echo
  printf "%b" "$LOCK_LINES"
} > "$BASE/sources.lock.new"
mv "$BASE/sources.lock.new" "$BASE/sources.lock"

echo "== готово: версии ${NEW_OVPNS# } =="
echo "Проверьте git diff build/ и соберите: bash build/build-all.sh"

#!/bin/bash
# Скачать тарболы исходников и XOR-патчи Tunnelblick на сервер (один раз).
set -euo pipefail
BASE="$(cd "$(dirname "$0")" && pwd)"
RAW="https://raw.githubusercontent.com/Tunnelblick/Tunnelblick/main/third_party/sources/openvpn"
OVPNS="2.5.9 2.6.20 2.7.4"
PATCHES="
02-tunnelblick-openvpn_xorpatch-a.diff
03-tunnelblick-openvpn_xorpatch-b.diff
04-tunnelblick-openvpn_xorpatch-c.diff
05-tunnelblick-openvpn_xorpatch-d.diff
06-tunnelblick-openvpn_xorpatch-e.diff
"
mkdir -p "$BASE/src"
for v in $OVPNS; do
  echo "== openvpn-$v =="
  wget -q -O "$BASE/src/openvpn-$v.tar.gz" "$RAW/openvpn-$v/openvpn-$v.tar.gz"
  mkdir -p "$BASE/patches/$v"
  for p in $PATCHES; do
    wget -q -O "$BASE/patches/$v/$p" "$RAW/openvpn-$v/patches/$p"
  done
done
echo "== fetched =="
du -h "$BASE"/src/*.tar.gz
find "$BASE/patches" -type f | sort

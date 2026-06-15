#!/bin/bash
# Полная матрица 3x3 (или подмножество через env DEBS / OVPNS).
# Логи в logs/, готовые .deb в out/.
set -uo pipefail
BASE="$(cd "$(dirname "$0")" && pwd)"
DEBS="${DEBS:-11 12 13}"
OVPNS="${OVPNS:-2.5.9 2.6.20 2.7.4}"
mkdir -p "$BASE/out" "$BASE/logs"
SUMMARY=""
for d in $DEBS; do
  for v in $OVPNS; do
    log="$BASE/logs/deb${d}-ovpn${v}.log"
    printf '>>> deb%s / openvpn-%s ... ' "$d" "$v"
    if bash "$BASE/build-one.sh" "$d" "$v" >"$log" 2>&1; then
      echo "OK"; SUMMARY="${SUMMARY}OK    deb${d} openvpn-${v}\n"
    else
      echo "FAIL (см. $log)"; SUMMARY="${SUMMARY}FAIL  deb${d} openvpn-${v}  -> $log\n"
    fi
  done
done
echo "==================== SUMMARY ===================="
printf "%b" "$SUMMARY"
echo "------------------------------------------------"
ls -la "$BASE/out"

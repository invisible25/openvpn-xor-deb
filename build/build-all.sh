#!/bin/bash
# Полная матрица Debian x OpenVPN (или подмножество через env DEBS / OVPNS).
# Версии OpenVPN по умолчанию берутся из sources.lock, а не прописываются здесь:
# иначе при обновлении их пришлось бы менять в двух местах, и рано или поздно
# скрипты разошлись бы.
# Логи в logs/, готовые .deb в out/.
set -uo pipefail
BASE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=sources.lock
. "$BASE/sources.lock"

DEBS="${DEBS:-11 12 13}"
OVPNS="${OVPNS_OVERRIDE:-$OVPNS}"

# Сборка начинается только с подтверждённых исходников.
OVPNS_OVERRIDE="$OVPNS" bash "$BASE/fetch-sources.sh" || { echo "исходники не подтверждены — сборка остановлена"; exit 2; }

mkdir -p "$BASE/out" "$BASE/logs"
SUMMARY=""
FAILED=0
for d in $DEBS; do
  for v in $OVPNS; do
    log="$BASE/logs/deb${d}-ovpn${v}.log"
    printf '>>> deb%s / openvpn-%s ... ' "$d" "$v"
    if bash "$BASE/build-one.sh" "$d" "$v" >"$log" 2>&1; then
      echo "OK"; SUMMARY="${SUMMARY}OK    deb${d} openvpn-${v}\n"
    else
      echo "FAIL (см. $log)"; SUMMARY="${SUMMARY}FAIL  deb${d} openvpn-${v}  -> $log\n"
      FAILED=$((FAILED + 1))
    fi
  done
done
echo "==================== SUMMARY ===================="
printf "%b" "$SUMMARY"
echo "------------------------------------------------"
ls -la "$BASE/out"

# Контрольные суммы готовых пакетов — те, что публикуются в SHA256SUMS.txt.
( cd "$BASE/out" && sha256sum ./*.deb > SHA256SUMS.txt ) 2>/dev/null || true
[ "$FAILED" -eq 0 ] || exit 1

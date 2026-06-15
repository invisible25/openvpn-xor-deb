#!/bin/bash
# Поднять изолированный одноразовый systemd-контейнер и прогнать E2E (e2e-inner.sh).
# Хост и его сервисы (remnanode/ewbuild) НЕ трогаются. Контейнер удаляется в конце.
set -uo pipefail
BASE="$(cd "$(dirname "$0")" && pwd)"
DEB_NAME="${1:-openvpn-xor_2.6.20-1~deb12_amd64.deb}"
DEB_PATH="$BASE/out/$DEB_NAME"
C=ovpn_e2e
IMG=debian:12

[ -f "$DEB_PATH" ] || { echo "нет файла $DEB_PATH"; exit 1; }

echo "=== cleanup previous (если был) ==="
docker rm -f "$C" >/dev/null 2>&1 || true

echo "=== старт systemd-контейнера (privileged, изолирован) ==="
docker run -d --name "$C" --privileged \
  --tmpfs /run --tmpfs /run/lock \
  -v /sys/fs/cgroup:/sys/fs/cgroup:rw --cgroupns=host \
  --device /dev/net/tun --cap-add NET_ADMIN \
  "$IMG" bash -c "apt-get update -qq && DEBIAN_FRONTEND=noninteractive apt-get install -y -qq systemd systemd-sysv dbus >/dev/null 2>&1; exec /lib/systemd/systemd"

echo "=== ждём поднятия systemd ==="
for i in $(seq 1 45); do
  state="$(docker exec "$C" systemctl is-system-running 2>/dev/null)"
  echo "  systemd: ${state:-(installing)}"
  echo "$state" | grep -qE 'running|degraded' && break
  sleep 2
done

echo "=== копируем .deb и inner-скрипт ==="
docker cp "$DEB_PATH" "$C:/root/$DEB_NAME"
docker cp "$BASE/e2e-inner.sh" "$C:/root/e2e-inner.sh"
docker exec "$C" sed -i 's/\r$//' /root/e2e-inner.sh
docker exec "$C" chmod +x /root/e2e-inner.sh

echo "=== запуск E2E внутри контейнера ==="
docker exec "$C" bash /root/e2e-inner.sh "/root/$DEB_NAME"
rc=$?

echo "=== teardown (удаляем контейнер) ==="
docker rm -f "$C" >/dev/null 2>&1 || true
echo "=== E2E rc=$rc ==="
exit $rc

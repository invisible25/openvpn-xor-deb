#!/bin/bash
# Smoke-тест overlay ВНУТРИ чистого контейнера целевой системы. Аргументы: <TAG> <OVPN>
# Падает (а не только печатает), если пакет не встал, XOR нет или откат не
# вернул штатный бинарь: этот тест — шаг CI, а не ручной осмотр.
set -euo pipefail
TAG="$1"; OVPN="$2"
export DEBIAN_FRONTEND=noninteractive
DEB_FILE="/work/out/openvpn-xor_${OVPN}-1~${TAG}_amd64.deb"

echo "### установка штатного openvpn (как делает Angristan через apt)"
apt-get update -qq
apt-get install -y -qq openvpn >/dev/null
echo "    stock: $(openvpn --version 2>&1 | head -1)"

echo "### dpkg -i нашего пакета"
apt-get install -y -qq "$DEB_FILE" >/dev/null
echo "--- divert ---"; dpkg-divert --list openvpn || true
ls -l /usr/sbin/openvpn /usr/sbin/openvpn.distrib 2>&1
echo "    active: $(openvpn --version 2>&1 | head -1)"
if grep -aqiE 'scramble|xormask|obfuscate' /usr/sbin/openvpn; then
  echo "    XOR: PRESENT в активном /usr/sbin/openvpn"
else
  echo "    XOR: MISSING (!)"; exit 1
fi
# Бинарь должен запускаться: зависимости от библиотек системы сошлись.
# openvpn --version завершается с кодом 1 — проверяем строку, а не код.
ver="$(/usr/sbin/openvpn --version 2>&1 | head -1 || true)"
case "$ver" in "OpenVPN ${OVPN} "*) ;; *) echo "    !!! не запускается или не та версия: $ver"; exit 1 ;; esac

echo "### откат: dpkg -r openvpn-xor"
dpkg -r openvpn-xor
ls -l /usr/sbin/openvpn 2>&1
echo "    restored: $(openvpn --version 2>&1 | head -1)"
if grep -aqiE 'scramble|xormask|obfuscate' /usr/sbin/openvpn; then
  echo "    !!! после отката всё ещё XOR — diversion не снялся"; exit 1
else
  echo "    OK: вернулся штатный бинарь"
fi

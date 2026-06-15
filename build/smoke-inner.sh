#!/bin/bash
# Smoke-тест overlay ВНУТРИ чистого контейнера debian:<DEB>. Аргументы: <DEB> <OVPN>
set -uo pipefail
DEB="$1"; OVPN="$2"
export DEBIAN_FRONTEND=noninteractive
DEB_FILE="/work/out/openvpn-xor_${OVPN}-1~deb${DEB}_amd64.deb"

echo "### установка штатного openvpn (как делает Angristan через apt)"
apt-get update -qq
apt-get install -y -qq openvpn >/dev/null
echo "    stock: $(openvpn --version 2>&1 | head -1)"

echo "### dpkg -i нашего пакета"
dpkg -i "$DEB_FILE" || apt-get -y -f install >/dev/null
echo "--- divert ---"; dpkg-divert --list openvpn || true
ls -l /usr/sbin/openvpn /usr/sbin/openvpn.distrib 2>&1
echo "    active: $(openvpn --version 2>&1 | head -1)"
if grep -aqiE 'scramble|xormask|obfuscate' /usr/sbin/openvpn; then
  echo "    XOR: PRESENT в активном /usr/sbin/openvpn"
else
  echo "    XOR: MISSING (!)"
fi

echo "### откат: dpkg -r openvpn-xor"
dpkg -r openvpn-xor
ls -l /usr/sbin/openvpn 2>&1
echo "    restored: $(openvpn --version 2>&1 | head -1)"
if grep -aqiE 'scramble|xormask|obfuscate' /usr/sbin/openvpn; then
  echo "    !!! после отката всё ещё XOR — diversion не снялся"
else
  echo "    OK: вернулся штатный бинарь"
fi

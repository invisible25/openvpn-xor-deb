#!/bin/bash
# E2E-проверка ВНУТРИ изолированного systemd-контейнера.
# Аргумент: путь к нашему .deb внутри контейнера.
# Сценарий: Angristan headless -> наш .deb (divert) -> scramble -> клиент через туннель -> ping.
set -uo pipefail
DEB="$1"
KEY="e2e-scramble-key-2026"
export DEBIAN_FRONTEND=noninteractive
L(){ echo; echo "=================== $* ==================="; }

L "wait for systemd"
for i in $(seq 1 30); do systemctl is-system-running 2>/dev/null | grep -qE 'running|degraded' && break; sleep 1; done
echo "systemd: $(systemctl is-system-running 2>/dev/null)"

L "base deps"
apt-get update -qq
apt-get install -y -qq curl ca-certificates iptables procps iproute2 iputils-ping >/dev/null
echo "ok"

L "download Angristan"
curl -fsSL -o /root/openvpn-install.sh https://raw.githubusercontent.com/angristan/openvpn-install/master/openvpn-install.sh
chmod +x /root/openvpn-install.sh
echo "dispatch hints:"; grep -nE 'NON_INTERACTIVE_INSTALL|"install"\)|\$1' /root/openvpn-install.sh | head

IP="$(hostname -I | awk '{print $1}')"
L "container IP = $IP"

L "Angristan headless install"
export NON_INTERACTIVE_INSTALL=y APPROVE_INSTALL=y APPROVE_IP=y CONTINUE=y
export ENDPOINT="$IP" ENDPOINT_TYPE=4 IP="$IP" PORT=1194 PROTOCOL=udp
export DNS=cloudflare CLIENT=e2e PASS=1 NEW_CLIENT=y
export IPV6_SUPPORT=n CLIENT_IPV4=y CLIENT_IPV6=n
/root/openvpn-install.sh </dev/null 2>&1 | tail -20 || true
if [ ! -f /etc/openvpn/server/server.conf ]; then
  echo "(retry with 'install' subcommand)"; /root/openvpn-install.sh install </dev/null 2>&1 | tail -20 || true
fi

L "stock server check"
if [ ! -f /etc/openvpn/server/server.conf ]; then echo "!!! Angristan не создал server.conf — стоп"; exit 2; fi
echo "stock binary: $(/usr/sbin/openvpn --version 2>&1 | head -1)"
echo "service: $(systemctl is-active openvpn-server@server 2>/dev/null)"

L "install our XOR .deb"
dpkg -i "$DEB" || apt-get -y -f install >/dev/null
echo "active binary: $(/usr/sbin/openvpn --version 2>&1 | head -1)"
dpkg-divert --list openvpn

L "enable scramble (server + client)"
grep -q '^scramble ' /etc/openvpn/server/server.conf || echo "scramble obfuscate $KEY" >> /etc/openvpn/server/server.conf
CLI="$(ls /root/*.ovpn 2>/dev/null | head -1)"
echo "client cfg: $CLI"
grep -q '^scramble ' "$CLI" || echo "scramble obfuscate $KEY" >> "$CLI"
echo "server scramble: $(grep '^scramble' /etc/openvpn/server/server.conf)"
echo "client scramble: $(grep '^scramble' "$CLI")"

L "restart server (проверка Type=notify с нашим бинарём)"
systemctl restart openvpn-server@server
sleep 2
echo "is-active: $(systemctl is-active openvpn-server@server)"
systemctl --no-pager status openvpn-server@server 2>&1 | head -8

L "connect client через scramble-туннель"
/usr/sbin/openvpn --config "$CLI" --route-nopull \
  --daemon --log /tmp/client.log --writepid /tmp/client.pid
for i in $(seq 1 25); do grep -q 'Initialization Sequence Completed' /tmp/client.log 2>/dev/null && break; sleep 1; done
echo "--- client log tail ---"; tail -18 /tmp/client.log

L "ping VPN-сервера 10.8.0.1 через туннель"
if ping -c 3 -W 2 10.8.0.1; then echo "RESULT: PING-OK (туннель со scramble работает)"; else echo "RESULT: PING-FAIL"; fi
echo "--- tun ifaces ---"; ip -br addr show 2>/dev/null | grep -i tun || true
[ -f /tmp/client.pid ] && kill "$(cat /tmp/client.pid)" 2>/dev/null || true

L "DONE"

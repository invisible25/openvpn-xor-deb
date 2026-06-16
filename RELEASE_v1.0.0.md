## v1.0.0 — OpenVPN + Tunnelblick XOR для Debian 11/12/13

9 пакетов: OpenVPN **2.5.9 / 2.6.20 / 2.7.4** × Debian **11 / 12 / 13**, архитектура **amd64**.

Пакет — тонкий overlay: через `dpkg-divert` подменяет `/usr/sbin/openvpn` XOR-сборкой (scramble,
обход DPI), оригинал → `/usr/sbin/openvpn.distrib`. Ставится поверх сервера от
[angristan/openvpn-install](https://github.com/angristan/openvpn-install); `apt remove openvpn-xor`
полностью откатывает.

### Особенности сборки
- XOR-патчи Tunnelblick `02..06` (scramble).
- `--disable-dco` (scramble работает в userspace) и `--enable-systemd` (для `Type=notify` в `openvpn-server@`).
- Зависимости посчитаны под каждый Debian (deb11→`libssl1.1`, deb13→`libssl3t64`).

### Установка
```bash
dpkg -i openvpn-xor_2.6.20-1-deb12_amd64.deb   # файл под свою версию Debian
# при нехватке зависимостей: apt install ./openvpn-xor_2.6.20-1-deb12_amd64.deb
```
Затем добавить `scramble obfuscate <КЛЮЧ>` в `/etc/openvpn/server/server.conf` и в каждый клиентский
`.ovpn`, перезапустить `systemctl restart openvpn-server@server`. Полная инструкция — в `УСТАНОВКА.md`.

> Клиент тоже должен быть с XOR-патчем (Tunnelblick и т.п.) — иначе соединение не встанет.

Сверка целостности — `SHA256SUMS.txt`.

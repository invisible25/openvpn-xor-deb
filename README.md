# openvpn-xor-deb

Готовые `.deb`-пакеты **OpenVPN с XOR-патчем Tunnelblick** (`scramble` — обфускация трафика для
обхода DPI) для Debian-серверов. Оформлены как **тонкий overlay**: пакет через `dpkg-divert`
подменяет штатный `/usr/sbin/openvpn` своим XOR-бинарём, оригинал сохраняет как
`/usr/sbin/openvpn.distrib`. Зависит от штатного `openvpn` — ставится **поверх** уже развёрнутого
сервера (например, скриптом [angristan/openvpn-install](https://github.com/angristan/openvpn-install)).

## Матрица (amd64)

| OpenVPN \ Debian | 11 (bullseye) | 12 (bookworm) | 13 (trixie) |
|---|---|---|---|
| **2.5.9**  | ✅ | ✅ | ✅ |
| **2.6.20** | ✅ | ✅ | ✅ |
| **2.7.4**  | ✅ | ✅ | ✅ |

Имя файла: `openvpn-xor_<версия>-1-deb<N>_amd64.deb`. Каждый пакет собран в matched-контейнере
`debian:N`, поэтому зависимости точны (deb11→`libssl1.1`, deb13→`libssl3t64`).

## Установка
```bash
# взять файл под свою версию Debian (см. таблицу), затем:
dpkg -i openvpn-xor_2.6.20-1-deb12_amd64.deb
# если ругнётся на зависимости:
apt install ./openvpn-xor_2.6.20-1-deb12_amd64.deb
```
Включение обфускации и подробная пошаговая инструкция — в [УСТАНОВКА.md](УСТАНОВКА.md).

> **Важно:** `scramble` нужен с обеих сторон — клиент тоже должен быть с XOR-патчем
> (Tunnelblick на macOS; патченые сборки на Windows/Linux/Android). Обычный «OpenVPN Connect» не подойдёт.

## Откат
```bash
apt remove openvpn-xor   # вернёт штатный /usr/sbin/openvpn из .distrib
```

## Сборка
Воспроизводимый харнесс — в [`build/`](build/) (Docker `debian:11/12/13`, патчи Tunnelblick,
`--disable-dco`, `--enable-systemd`). Контрольные суммы релиза — `SHA256SUMS.txt`.

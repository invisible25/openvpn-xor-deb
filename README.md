# openvpn-xor-deb

Готовые `.deb`-пакеты **OpenVPN с XOR-патчем Tunnelblick** (`scramble` — обфускация трафика для
обхода DPI) для Debian-серверов. Оформлены как **тонкий overlay**: пакет через `dpkg-divert`
подменяет штатный `/usr/sbin/openvpn` своим XOR-бинарём, оригинал сохраняет как
`/usr/sbin/openvpn.distrib`. Зависит от штатного `openvpn` — ставится **поверх** уже развёрнутого
сервера (например, скриптом [angristan/openvpn-install](https://github.com/angristan/openvpn-install)).

## Матрица (amd64)

| OpenVPN \ Debian | 11 (bullseye) | 12 (bookworm) | 13 (trixie) |
|---|---|---|---|
| **2.5.11** | ✅ | ✅ | ✅ |
| **2.6.23** | ✅ | ✅ | ✅ |
| **2.7.7**  | ✅ | ✅ | ✅ |

Версии — последние подписанные релизы каждой ветки. Ветка 2.5 вышла из поддержки
OpenVPN; для новых серверов берите 2.6 или 2.7.

Имя файла: `openvpn-xor_<версия>-1~deb<N>_amd64.deb`. Каждый пакет собран в matched-контейнере
`debian:N`, поэтому зависимости точны (deb11→`libssl1.1`, deb13→`libssl3t64`).

## Установка
```bash
# взять файл под свою версию Debian (см. таблицу), затем:
dpkg -i openvpn-xor_2.6.23-1~deb12_amd64.deb
# если ругнётся на зависимости:
apt install ./openvpn-xor_2.6.23-1~deb12_amd64.deb
```
Включение обфускации и подробная пошаговая инструкция — в [УСТАНОВКА.md](УСТАНОВКА.md).

> **Важно:** `scramble` нужен с обеих сторон — клиент тоже должен быть с XOR-патчем
> (Tunnelblick на macOS; патченые сборки на Windows/Linux/Android). Обычный «OpenVPN Connect» не подойдёт.

## Откат
```bash
apt remove openvpn-xor   # вернёт штатный /usr/sbin/openvpn из .distrib
```

## Сборка

Воспроизводимый харнесс — в [`build/`](build/): Docker `debian:11/12/13`, XOR-патчи
Tunnelblick, `--disable-dco`, `--enable-systemd`.

```bash
bash build/build-all.sh                      # вся матрица
DEBS=13 OVPNS_OVERRIDE=2.6.23 bash build/build-all.sh   # одна ячейка
```

### Откуда берутся исходники

Раньше `fetch-sources.sh` скачивал тарболы и патчи из `main` репозитория Tunnelblick
по жёстко заданным версиям. Tunnelblick держит в `main` только последнюю версию
каждой ветки и удаляет предыдущие, поэтому сборка ломалась при каждом их обновлении
(404 на 2.6.20 и 2.7.4).

Теперь:

| Что | Откуда | Проверка |
|---|---|---|
| Тарболы OpenVPN | официальные релизы [OpenVPN/openvpn](https://github.com/OpenVPN/openvpn/releases) — старые не удаляются | SHA-256 из `build/sources.lock` **и** подпись OpenVPN |
| XOR-патчи 02..06 | лежат в `build/patches/<версия>/` прямо в репозитории | коммит Tunnelblick, из которого взяты, записан в `sources.lock` |
| Ключ подписи | `build/keys/openvpn-security.asc` | отпечаток основного ключа закреплён в `sources.lock` |

Любое расхождение останавливает сборку: неподтверждённый код openvpn потом встанет
на все ноды. Подпись сверяется с **основным** ключом
`F554 A368 7412 CFFE BDEF E0A3 12F5 F7B4 2F2B 01E7` (OpenVPN Security Mailing List),
а не с подключом — подключи OpenVPN ротирует.

Патч Tunnelblick `10-route-gateway-dhcp.diff` намеренно не применяется: он про
маршрутизацию через DHCP-шлюз на macOS и к обфускации отношения не имеет.

### Обновление до новых версий

```bash
bash build/update-sources.sh   # нужны curl, jq, gpg
git diff build/                # проверить, что изменилось
bash build/build-all.sh
```

Скрипт берёт последние подписанные версии веток из Tunnelblick, забирает их патчи
и пересчитывает контрольные суммы. Git-снапшоты Tunnelblick (вида `2.5_git_37160ee`)
пропускаются: у них нет подписи OpenVPN, а `_` недопустим в версии deb-пакета.

**Основной ключ подписи OpenVPN действует до 2027-02-07.** После продления OpenVPN
обновите его тем же `update-sources.sh`, иначе проверка подписей начнёт падать.

Контрольные суммы готовых пакетов — `SHA256SUMS.txt`.

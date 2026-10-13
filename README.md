# openvpn-xor-deb

Готовые `.deb`-пакеты **OpenVPN с XOR-патчем Tunnelblick** (`scramble` — обфускация трафика для
обхода DPI) для серверов Debian и Ubuntu. Оформлены как **тонкий overlay**: пакет через `dpkg-divert`
подменяет штатный `/usr/sbin/openvpn` своим XOR-бинарём, оригинал сохраняет как
`/usr/sbin/openvpn.distrib`. Зависит от штатного `openvpn` — ставится **поверх** уже развёрнутого
сервера (например, скриптом [angristan/openvpn-install](https://github.com/angristan/openvpn-install)).

## Матрица (amd64), собирается в CI

| OpenVPN \ система | Debian 12 | Debian 13 | Ubuntu 22.04 | Ubuntu 24.04 | Ubuntu 26.04 |
|---|---|---|---|---|---|
| **2.6.23** | ✅ | ✅ | ✅ | ✅ | ✅ |
| **2.7.7**  | ✅ | ✅ | ✅ | ✅ | ✅ |

Версии — последние подписанные релизы веток. Ubuntu — только LTS: промежуточные выпуски
живут по 9 месяцев.

Имя файла в релизе: `openvpn-xor_<версия>-1-<цель>_amd64.deb`, цель — `deb12`, `deb13`,
`ubuntu22.04`, `ubuntu24.04`, `ubuntu26.04` (в версии пакета вместо дефиса `~`). Каждый пакет
собран в контейнере той же системы, поэтому зависимости точны (glibc, `libssl3` против
`libssl3t64`), и в CI же установлен поверх штатного openvpn, запущен и откачен.

## Установка
```bash
# взять файл под свою систему (см. таблицу), затем:
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

#!/bin/bash
# Сборка одной ячейки матрицы ВНУТРИ контейнера debian:<DEB>.
# Аргументы: <DEB> <OVPN>, напр.: inner.sh 12 2.6.20
set -euo pipefail

DEB="$1"; OVPN="$2"
WORK=/work
OUT="$WORK/out"
BUILD="/tmp/build-${OVPN}-deb${DEB}"
STAGE="/tmp/stage-${OVPN}-deb${DEB}"
export DEBIAN_FRONTEND=noninteractive

echo "==================================================================="
echo "### BUILD deb${DEB} / openvpn-${OVPN}"
echo "==================================================================="

echo "### [1/6] apt build-deps"
apt-get update -qq
apt-get install -y -qq --no-install-recommends \
  build-essential autoconf automake libtool autoconf-archive pkg-config \
  libssl-dev liblzo2-dev liblz4-dev libcap-ng-dev libsystemd-dev libpam0g-dev \
  ca-certificates xz-utils dpkg-dev fakeroot patch >/dev/null
echo "    ok"

echo "### [2/6] unpack"
rm -rf "$BUILD"; mkdir -p "$BUILD"
tar -xf "$WORK/src/openvpn-${OVPN}.tar.gz" -C "$BUILD"
SRC="$BUILD/openvpn-${OVPN}"
cd "$SRC"

echo "### [3/6] apply XOR patches 02..06"
find . \( -name '*.am' -o -name 'configure.ac' -o -name 'configure.in' \) -print0 \
  | xargs -0 md5sum 2>/dev/null | sort > /tmp/am.before || true
for p in "$WORK"/patches/"$OVPN"/0[2-6]-*.diff; do
  echo "    -> $(basename "$p")"
  patch -p1 --batch --forward < "$p"
done
find . \( -name '*.am' -o -name 'configure.ac' -o -name 'configure.in' \) -print0 \
  | xargs -0 md5sum 2>/dev/null | sort > /tmp/am.after || true
if ! diff -q /tmp/am.before /tmp/am.after >/dev/null 2>&1; then
  echo "### [3b] autotools inputs changed -> autoreconf -fvi"
  autoreconf -fvi
fi

echo "### [4/6] configure + make"
# systemd: задаём флаги напрямую — PKG_CHECK_MODULES их примет без обращения к
# pkg-config (провайдер модуля 'systemd' разнится по версиям Debian). Заголовок
# sd-daemon.h и сама libsystemd.so приходят из libsystemd-dev.
export libsystemd_CFLAGS=" "
export libsystemd_LIBS="-lsystemd"
./configure \
  --prefix=/usr \
  --disable-dco \
  --disable-debug \
  --enable-systemd \
  --enable-lzo \
  --enable-lz4 \
  --disable-dependency-tracking \
  >/dev/null
make -j"$(nproc)" >/dev/null
echo "    built: $(./src/openvpn/openvpn --version 2>&1 | head -1 || true)"

echo "### [5/6] stage + XOR check"
rm -rf "$STAGE"
install -D -m0755 src/openvpn/openvpn "$STAGE/usr/sbin/openvpn"
strip "$STAGE/usr/sbin/openvpn"
if grep -aoiE 'scramble|xormask|obfuscate' "$STAGE/usr/sbin/openvpn" | sort -u | grep -q .; then
  echo "    XOR markers: PRESENT ($(grep -aoiE 'scramble|xormask|obfuscate' "$STAGE/usr/sbin/openvpn" | sort -uf | tr '\n' ' '))"
else
  echo "    !!! XOR markers MISSING — aborting"; exit 3
fi

echo "### [6/6] package (.deb)"
# shared-lib deps через dpkg-shlibdeps (точно под этот Debian, включая t64)
mkdir -p debian
printf 'Source: openvpn-xor\nPackage: openvpn-xor\nArchitecture: amd64\n' > debian/control
SHLIBS="$(dpkg-shlibdeps -O --ignore-missing-info "$STAGE/usr/sbin/openvpn" 2>/dev/null \
          | sed -n 's/^shlibs:Depends=//p' || true)"
if [ -z "$SHLIBS" ]; then
  SHLIBS="libc6, libssl3 | libssl1.1 | libssl3t64, liblzo2-2, liblz4-1, libcap-ng0, libsystemd0 | libsystemd0t64, libpam0g"
  echo "    (shlibdeps fallback used)"
fi
DEPENDS="openvpn (>= 2.4), ${SHLIBS}"

mkdir -p "$STAGE/DEBIAN"
cat > "$STAGE/DEBIAN/control" <<EOF
Package: openvpn-xor
Version: ${OVPN}-1~deb${DEB}
Architecture: amd64
Maintainer: Invisible Net VPN <invisible2584@gmail.com>
Depends: ${DEPENDS}
Section: net
Priority: optional
Homepage: https://github.com/Tunnelblick/Tunnelblick
Description: OpenVPN ${OVPN} with Tunnelblick XOR scramble patch (binary overlay)
 Drop-in replacement for /usr/sbin/openvpn built with the Tunnelblick XOR
 scramble patches (DPI obfuscation), with DCO disabled. Installed via
 dpkg-divert: the stock binary is kept as /usr/sbin/openvpn.distrib and
 restored on removal. Units, configs and plugins come from the stock
 openvpn package, which is a dependency.
EOF

install -m0755 "$WORK/debian-tmpl/preinst"  "$STAGE/DEBIAN/preinst"
install -m0755 "$WORK/debian-tmpl/postrm"   "$STAGE/DEBIAN/postrm"
install -m0755 "$WORK/debian-tmpl/postinst" "$STAGE/DEBIAN/postinst"

mkdir -p "$OUT"
DEBFILE="$OUT/openvpn-xor_${OVPN}-1~deb${DEB}_amd64.deb"
dpkg-deb --build --root-owner-group "$STAGE" "$DEBFILE"
echo "### DONE: $DEBFILE"
dpkg-deb -I "$DEBFILE" | sed 's/^/    /'
echo "    contents:"; dpkg-deb -c "$DEBFILE" | sed 's/^/    /'

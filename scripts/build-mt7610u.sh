#!/usr/bin/env bash
# build-mt7610u.sh — run ON THE LYRA as root.
# Builds the in-kernel mt76x0u driver against the running beapig 6.1.99 kernel,
# works around the stale built-in-module conflict, installs firmware, and loads it.
#
# Usage: sudo ./build-mt7610u.sh /path/to/mt76 [/path/to/sources/firmware]
set -euo pipefail

MT76_SRC="${1:?Usage: sudo $0 /path/to/mt76 [firmware-dir]}"
FW_DIR="${2:-$(dirname "$MT76_SRC")/firmware}"
KREL="$(uname -r)"
KBUILD="/lib/modules/${KREL}/build"
STALE_DIR="/root/stale-ko"

[[ $EUID -eq 0 ]] || { echo "Must run as root." >&2; exit 1; }
[[ -d "$MT76_SRC" ]] || { echo "mt76 source dir not found: $MT76_SRC" >&2; exit 1; }
[[ -d "$KBUILD" ]] || { echo "Kernel headers missing at $KBUILD" >&2; exit 1; }

echo "==> Kernel: ${KREL}"

echo "==> Installing firmware"
install -d /lib/firmware/mediatek
if [[ -f "${FW_DIR}/mediatek/mt7610u.bin" ]]; then
  install -m644 "${FW_DIR}/mediatek/mt7610u.bin" /lib/firmware/mediatek/mt7610u.bin
  echo "    installed mt7610u.bin"
else
  echo "    WARNING: ${FW_DIR}/mediatek/mt7610u.bin not found — install it manually if load fails."
fi

echo "==> Building mt76 modules (gcc version-mismatch warning is harmless)"
make -C "$KBUILD" M="$MT76_SRC" \
  CONFIG_MT76_CORE=m CONFIG_MT76_USB=m CONFIG_MT76x02_LIB=m \
  CONFIG_MT76x02_USB=m CONFIG_MT76x0_COMMON=m CONFIG_MT76x0U=m modules

echo "==> Installing modules to updates/mt76"
install -d "/lib/modules/${KREL}/updates/mt76"
find "$MT76_SRC" -name '*.ko' -exec cp -v {} "/lib/modules/${KREL}/updates/mt76/" \;

echo "==> Moving stale built-in .ko files aside (fixes 'Exec format error')"
# mac80211/cfg80211/libarc4 are built into this kernel, but the image also leaves stale
# .ko copies that break modprobe with a duplicate-symbol error. Move a stale .ko aside
# ONLY when its symbol is confirmed built into the running kernel via /proc/kallsyms.
mkdir -p "$STALE_DIR"
move_if_builtin() {  # $1 = symbol, $2 = ko path
  local sym="$1" ko="$2"
  [[ -f "$ko" ]] || return 0
  if grep -q " ${sym}\$" /proc/kallsyms || grep -q " ${sym} " /proc/kallsyms; then
    mv -v "$ko" "$STALE_DIR/"
  else
    echo "    leaving $(basename "$ko") in place (symbol ${sym} not built in)"
  fi
}
move_if_builtin ieee80211_alloc_hw "/lib/modules/${KREL}/kernel/net/mac80211/mac80211.ko"
move_if_builtin arc4_crypt         "/lib/modules/${KREL}/kernel/lib/crypto/libarc4.ko"
# cfg80211 is usually built in too; only moved if confirmed:
move_if_builtin wiphy_register     "/lib/modules/${KREL}/kernel/net/wireless/cfg80211.ko"

echo "==> depmod"
depmod -a

echo "==> Loading mt76x0u"
modprobe -v mt76x0u

echo
echo "==> Done. New interface (if any):"
ip -br link show | grep -E '^wlx' || echo "    (no wlx* yet — check: dmesg | tail -40)"
echo
echo "Next: nmcli --ask device wifi connect \"<SSID>\""

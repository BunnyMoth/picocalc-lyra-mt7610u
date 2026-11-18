#!/usr/bin/env bash
# fetch-sources.sh — run on a NETWORKED Linux box (not the Lyra, which has no WiFi yet).
# Downloads the mt76 driver source matching kernel 6.1.99 and the MT7610U firmware,
# into ./sources/ ready to scp to the board.
set -euo pipefail

KVER="${KVER:-6.1.99}"
OUT="${OUT:-$(pwd)/sources}"
MT76_SUBPATH="linux-${KVER}/drivers/net/wireless/mediatek/mt76"

mkdir -p "$OUT"
cd "$OUT"

echo "==> Fetching Linux ${KVER} (mt76 subtree only)"
curl -fLO "https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-${KVER}.tar.gz"
tar -xzf "linux-${KVER}.tar.gz" "${MT76_SUBPATH}"
rm -rf mt76
mv "${MT76_SUBPATH}" ./mt76
rm -rf "linux-${KVER}" "linux-${KVER}.tar.gz"

echo "==> Fetching MT7610U firmware"
mkdir -p firmware/mediatek
curl -fL -o firmware/mediatek/mt7610u.bin \
  "https://git.kernel.org/pub/scm/linux/kernel/git/firmware/linux-firmware.git/plain/mediatek/mt7610u.bin"

cat <<EOF

==> Done. Contents of ${OUT}:
$(find "$OUT" -maxdepth 2 -type d | sed 's/^/    /')

Next: copy to the Lyra over the USB-gadget link, e.g.
    scp -r "${OUT}" root@192.168.123.100:/root/
Then on the Lyra:
    sudo ./scripts/build-mt7610u.sh /root/sources/mt76
EOF

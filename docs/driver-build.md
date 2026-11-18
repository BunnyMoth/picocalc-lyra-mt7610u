# Building the `mt76x0u` driver for the MT7610U on beapig 6.1.99

The beapig `v260814` image runs kernel **6.1.99** but ships **without** the `mt76x0u`
module, so the MT7610U is dead on arrival. This builds it from the matching mainline
`mt76` source and works around a built-in-module conflict unique to this image.

## 0. Confirm the dongle and kernel

```bash
lsusb | grep 0e8d:7610          # MediaTek MT7610U
uname -r                        # expect 6.1.99
ls /usr/src/linux-headers-$(uname -r)   # headers must be present (they are on v260814)
```

If `lsusb` shows the dongle as a CD-ROM / flash device instead (`0e8d:xxxx` mass storage),
it's in Windows-driver "ZeroCD" mode — `usb_modeswitch` it to WiFi mode first.

## 1. Fetch the source + firmware (on a networked machine)

The board has no WiFi yet, so grab everything on a networked Linux box and copy it across
the USB-gadget link. `scripts/fetch-sources.sh` does the download:

- `mt76` driver source, pulled from the **6.1.99** mainline tree so it matches the running
  kernel exactly (`drivers/net/wireless/mediatek/mt76`).
- `mt7610u.bin` firmware from `linux-firmware`.

Then copy to the Lyra (default gadget IP on this image is `192.168.123.100`, or
`192.168.137.100` under Windows ICS):

```bash
scp -r sources root@192.168.123.100:/root/
```

## 2. Build + install on the device

```bash
sudo ./scripts/build-mt7610u.sh /root/sources/mt76
```

What the script does, and why:

### 2a. Compile mt76 as modules

```bash
make -C /lib/modules/$(uname -r)/build M=$PWD \
  CONFIG_MT76_CORE=m CONFIG_MT76_USB=m CONFIG_MT76x02_LIB=m \
  CONFIG_MT76x02_USB=m CONFIG_MT76x0_COMMON=m CONFIG_MT76x0U=m modules
```

(The gcc-13 vs kernel-gcc-10 version warning is harmless.)

### 2b. The stale-module gotcha — the part that actually bites

`mac80211`, `cfg80211` and `libarc4` are **built into** the running beapig kernel, but the
image *also* leaves stale `.ko` files for them under `/lib/modules/6.1.99/`. When you load
`mt76x0u`, the kernel tries to pull in those stale `.ko`s and fails:

```
modprobe: ERROR: could not insert 'mac80211': Exec format error
# dmesg:
mac80211: exports duplicate symbol ieee80211_... (owned by kernel)
```

Note `/lib/modules/6.1.99/modules.builtin` does **not** match the running kernel, so you
can't trust it to tell you what's built in. Confirm a symbol is built-in directly:

```bash
grep ' ieee80211_alloc_hw' /proc/kallsyms    # a hit = mac80211 is built in
```

Fix: move the stale modules aside so modprobe uses the built-in versions, then `depmod`:

```bash
mkdir -p /root/stale-ko
mv /lib/modules/$(uname -r)/kernel/net/mac80211/mac80211.ko     /root/stale-ko/ 2>/dev/null || true
mv /lib/modules/$(uname -r)/kernel/lib/crypto/libarc4.ko        /root/stale-ko/ 2>/dev/null || true
depmod -a
```

### 2c. Load

```bash
modprobe -v mt76x0u
```

`dmesg` will say `mt7610e.bin not found, switching to mediatek/mt7610u.bin` — that is
**normal**, not an error. A new interface (`wlxXXXXXXXXXXXX`) should appear in `ip link`.

## 3. Connect with NetworkManager

NetworkManager is installed but may not be running, and it will fight the USB-gadget
interface unless you tell it to leave `usb0` alone:

```bash
mkdir -p /etc/NetworkManager/conf.d
printf '[keyfile]\nunmanaged-devices=interface-name:usb0\n' \
  > /etc/NetworkManager/conf.d/99-unmanaged-usb0.conf
systemctl enable --now NetworkManager
nmcli --ask device wifi connect "<SSID>"
ip route del default via 192.168.123.1 2>/dev/null   # drop gadget default so traffic uses WiFi
```

## 4. Persistence

The driver auto-loads and NetworkManager auto-reconnects after reboot. Two things the image
resets on boot that you may want to pin:

- `usb0` reverts to `192.168.123.100` (image default) — re-apply your static if you use the
  gadget link as a fallback.
- No RTC: if the clock is stale, `apt` may complain `Release file is not valid yet` until
  NTP syncs once WiFi is up.

## Rebuilds

If you ever rebuild or change the kernel, the `mt76` modules under
`/lib/modules/6.1.99/updates/mt76/` must be rebuilt against the new kernel.

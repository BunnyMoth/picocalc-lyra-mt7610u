# MT7610U Wi-Fi (monitor-mode capable) on the Luckfox Lyra / PicoCalc

Getting a **MediaTek MT7610U** USB Wi-Fi dongle working — including **monitor mode and
injection** — on a **Luckfox Lyra M** (RK3506G2, armhf) running the **beapig Ubuntu 24.04
`v260814` image** (kernel **6.1.99**) inside a ClockworkPi PicoCalc.

## Why this repo exists

The Luckfox Lyra / PicoCalc community has WiFi well covered on the **mechanical** side
(internal MX1.25 cable routing, socket mods, etc. — see
[the clockworkpi forum thread](https://forum.clockworkpi.com/t/wi-fi-for-the-luckfox-lyra/21630)),
and on the **Realtek / AIC** driver side.

What is *not* documented anywhere I could find:

- Getting the **MediaTek MT7610U** (`0e8d:7610`) going specifically — the community runs
  almost entirely Realtek (RTL8811AU/RTL8188) and AIC8800 chips.
- Building the **in-kernel `mt76x0u`** driver against the beapig `6.1.99` kernel, and the
  **stale built-in-module conflict** that makes `modprobe` fail with `Exec format error`
  until you move the leftover `mac80211.ko` / `libarc4.ko` aside.
- **Monitor mode + injection** on this platform. Everyone else uses WiFi for connectivity
  only (ssh client, Meshtastic). The MT7610U does monitor natively via `mt76`, which makes
  the Lyra a viable handheld 802.11 capture platform.

This repo fills exactly that gap. It is **not** a general "how to add WiFi to a PicoCalc"
guide — for the physical install, the forum thread above is the reference.

## Hardware

| | |
|---|---|
| Board | Luckfox Lyra M (RK3506G2, 3×Cortex-A7, 128 MB RAM, SD-boot, no NAND) |
| Carrier | ClockworkPi PicoCalc v2.0 |
| OS image | `Ubuntu24.04_for_PicoCalc` **v260814** (beapig, 2026-08-14), kernel **6.1.99** |
| Dongle | MediaTek MT7610U, `0e8d:7610`, AC600 dual-band (2.4 + 5 GHz) |
| Connection | MX1.25 4-pin → USB cable, routed internally (dongle lives inside the case) |

> **Power note:** the Lyra's MX1.25 `Vcc` reads ~3.3 V on battery and ~5 V when the PicoCalc
> is powered over USB. The MT7610U tolerates this range in practice; a hungrier dongle may
> want a 5 V boost converter.

## Quick start

On the device (the beapig image already ships kernel headers in `/usr/src`):

```bash
# 1. Get the mt76 source + firmware onto the board.
#    No WiFi yet, so fetch on a networked machine and copy over the USB-gadget link:
./scripts/fetch-sources.sh            # run on a networked Linux box
#    ...then scp the resulting ./sources/ dir to the Lyra (see docs/driver-build.md)

# 2. Build + install the driver (on the Lyra, as root):
sudo ./scripts/build-mt7610u.sh ./sources/mt76

# 3. Bring it up:
nmcli --ask device wifi connect "<SSID>"
```

Full walkthrough: **[docs/driver-build.md](docs/driver-build.md)**
Monitor mode / capture: **[docs/monitor-mode.md](docs/monitor-mode.md)**

## Status

Confirmed working: association to WPA2 and WPA3/SAE 5 GHz networks, DHCP, ~10–15 ms ping,
survives reboot (driver auto-loads, NetworkManager auto-reconnects), and `iw list` reports
`monitor`, `AP`, `IBSS`, `P2P` interface modes. End-to-end WPA handshake / PMKID capture
validated with `hcxdumptool` against the author's own network.

## Scope & ethics

Monitor mode and capture tooling here are for auditing **your own** networks and lab gear.
Don't point them at networks you don't own or have explicit permission to test.

## License

MIT (see `LICENSE`). Provided as-is; flashing and soldering are at your own risk.

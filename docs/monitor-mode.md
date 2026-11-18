# Monitor mode & capture on the MT7610U

The `mt76` driver gives the MT7610U native monitor mode and injection — no Nexmon-style
firmware patching needed (unlike the Pi's onboard chip). That's what makes the Lyra usable
as a handheld 802.11 capture platform.

## Confirm the radio can do it

```bash
iw list | sed -n '/Supported interface modes/,/Band/p'
```

Expected to include:

```
 * managed
 * AP
 * monitor
 * mesh point   (IBSS / P2P also listed)
```

## The single-radio constraint (read this first)

There is one radio. A monitor/capture interface and your managed (connected) interface share
the same `phy0`. **Starting a capture takes over the radio and drops your WiFi + SSH-over-WiFi.**

So run captures either:

- from the **PicoCalc keyboard directly**, or
- over the **USB-gadget link** (`ssh root@192.168.123.100` / `192.168.137.100`), which is a
  separate interface and stays up while the radio is in monitor mode.

## Capture with hcxdumptool

Installed tooling that has an armhf build on noble: `hcxdumptool` (6.3.1), `hcxtools`,
`tcpdump`. (`aircrack-ng` has **no** armhf build in noble — you don't need it for this.)

**Important:** hcxdumptool 6.3.1 refuses a logical interface (`mon0`). Give it the
**physical** interface name and it sets monitor mode itself:

```bash
iw dev mon0 del 2>/dev/null          # remove any leftover monitor iface
systemctl stop NetworkManager        # stop NM from reclaiming the radio

# band: a = 2.4 GHz, b = 5 GHz, c = 6 GHz. 11a = channel 11 on 2.4 GHz.
hcxdumptool -i wlxXXXXXXXXXXXX -w /root/cap-$(date +%s).pcapng -c 11a

# Ctrl+C to stop, then restore connectivity and convert:
systemctl start NetworkManager
hcxpcapngtool -o /root/out.hash /root/cap-*.pcapng
```

`out.hash` is `hashcat -m 22000` (WPA*01* PMKID / WPA*02* handshake) format.

## Targets

WPA2 (e.g. a 2.4 GHz network you own) yields crackable PMKID/handshake material. **WPA3/SAE**
(5 GHz) is a fine *connectivity* target but **not** a useful handshake target — SAE resists
offline cracking, so don't expect usable hashes from it.

Test your own gear only.

## Where this goes next

A working `--headless` 802.11 capture tool on the MT7610U is the prerequisite for a
Rust/ratatui capture "pet" UI on the PicoCalc LCD (an Oxigotchi-style build powered by
AngryOxide). Because the MT7610U does monitor natively, the Nexmon firmware layer that
Pi-based builds need can be dropped entirely.

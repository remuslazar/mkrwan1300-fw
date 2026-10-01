# MKR WAN 1310 module firmware (remuslazar fork)

Firmware for the Murata CMWX1ZZABZ-078 module (STM32L072 + SX1276) on the
Arduino MKR WAN 1300/1310: the AT-command LoRaWAN modem the SAMD21 talks to.
It is Arduino's [mkrwan1300-fw](https://github.com/arduino/mkrwan1300-fw),
derived from ST's I-CUBE-LRWAN AT_Slave example for the B-L072Z-LRWAN1 kit,
which carries the same module.

## What this fork adds

| Change | Why |
| --- | --- |
| [Downlink hold, `AT+DLHOLD`](#downlink-hold-atdlhold) | a SAMD21 in deep sleep loses every downlink with stock firmware; the module now keeps it and signals the SAMD21 on `LORA_IRQ` |
| [`build.sh`](#build) with a pinned toolchain | reproducible builds on a current Mac; upstream documents only System Workbench for STM32 |
| this README | build, flash and version notes upstream never had for the 1.3.1 line |

Everything stays AT-compatible with Arduino's
[MKRWAN_v2](https://github.com/arduino-libraries/MKRWAN_v2) library: new
behaviour is opt-in, and with it off the firmware behaves as upstream 1.3.1.

## Why this is not upstream

Upstream is dormant. The 1.3.1 line, the one MKRWAN_v2 uses, last changed on
2020-10-14; the last release of any line is 1.2.3 from 2021-05-18. Since then
MKRWAN_v2 has had only automated dependency updates, and nothing has been
merged for the firmware:

- The downlink loss has been reported since 2018 —
  [MKRWAN#36](https://github.com/arduino-libraries/MKRWAN/issues/36) (open,
  with workarounds and a proposed fix from 2020, never answered by a
  maintainer) and
  [MKRWAN_v2#24](https://github.com/arduino-libraries/MKRWAN_v2/issues/24)
  (open since 2022, no reply).
- The SAMD21-side approach, waking on UART traffic, was proposed in
  [ArduinoLowPower#20](https://github.com/arduino-libraries/ArduinoLowPower/pull/20)
  and [ArduinoCore-samd#427](https://github.com/arduino/ArduinoCore-samd/pull/427);
  both were closed without a merge.
- Community fixes to this firmware wait as open pull requests: #25, #27, #35.

The fix also depends on how the MKR WAN boards wire the module (its PA4 to
the SAMD21's PA28), while the code is ST's generic project for their own kit,
so it is not a drop-in for every user of the code base. It can still be
offered upstream as a pull request; nothing here depends on that being merged.

## Branches

| Branch | Content |
| --- | --- |
| `remus-1.3.1` (default) | this fork's work, based on upstream `master-1.3.1` |
| `master-1.3.1` | upstream 1.3.1, the ST-based firmware MKRWAN_v2 expects |
| `master` | upstream 1.2.3, the older line for the MKRWAN library |
| `experiment-1.4.0` | upstream's abandoned LoRaMac-node import |

The upstream remote is `upstream`; `git fetch upstream` shows if it ever moves.

## Build

Step by step, for building and flashing alike: [docs/flashing.md](docs/flashing.md).

```sh
./build.sh
```

It needs PlatformIO (`brew install platformio`); the script installs the pinned
toolchain on first use. A clean build takes a few seconds and writes
`mlm32l07x01.bin` and `fw.h`. Builds are not byte-identical to Arduino's
release binaries, which were made with another compiler.

## Flash

The module's STM32 has a ROM bootloader on its UART, reached through the
SAMD21: the SAMD21 holds BOOT0 high, resets the module and relays USB to the
module's UART (115200 baud, 8E1). The ROM bootloader cannot be overwritten, so
any image — Arduino's original included — can always be flashed again.

Either way works:

- **Standalone sketch**: copy MKRWAN_v2's `MKRWANFWUpdate_standalone` example,
  replace its `fw.h` with the one from `./build.sh`, and upload it to the SAMD21.
  It flashes the module and prints the result on the serial monitor.
- **Bridge and stm32flash**: upload MKRWAN_v2's `FWUpdaterBridge` example, then
  `stm32flash -b 115200 -m 8e1 -w mlm32l07x01.bin -v -g 0x0 /dev/cu.usbmodem…`
  (`brew install stm32flash`).

Then upload the real sketch to the SAMD21 again; the module keeps its firmware.

The module's SWD pins are also on test pads (`ST_SWDIO`, `ST_SWCLK`, `ST_RST`,
`ST_BOOT0` in the 1310 schematic) for an ST-LINK, if a debugger is needed.

## Downlink hold (`AT+DLHOLD`)

Stock firmware prints a downlink the moment it arrives, as an asynchronous
`+EVT:<port>:<hex>` line plus a `+EVT:RX…, RSSI …, SNR …` line. A SAMD21 in
deep sleep misses those bytes and the downlink is gone.

`AT+DLHOLD=1` holds the downlink instead and raises the module's PA4, which the
MKR WAN 1310 wires to the SAMD21's PA28 (`LORA_IRQ`). The held `+EVT` lines go
out in front of the output of the host's next AT command, whatever it is, and
PA4 drops again. MKRWAN_v2 parses `+EVT` inside any command's response, so the
downlink lands in the library's receive buffer as usual. `AT+RECV`, `AT+RECVB`
and their `=?` forms release PA4 without the `+EVT` lines, since they print the
data themselves.

The held lines are written completely, waiting for room in the module's
256-byte output queue, and the queue drains before the command runs, so its
reply is never lost behind them. At 9600 baud a 115-byte downlink (the most
TTN sends in RX2) takes about 0.3 s. `AT+RECV` and `AT+RECVB` write their output
the same way, in either mode. With `AT+DLHOLD=0` the asynchronous `+EVT` works
as in stock firmware, which drops what does not fit: downlinks beyond about 50
bytes arrive truncated there.

| Command | Effect |
| --- | --- |
| `AT+DLHOLD=0` | default: print `+EVT` at once, PA4 unused (analog), as stock |
| `AT+DLHOLD=1` | hold `+EVT` until the next command, PA4 high while one waits |
| `AT+DLHOLD=?` | current mode |

There is one slot: a second downlink before the host's next command replaces
the first (only possible in class B/C). The mode is not stored, and the
library's `modem.begin()` resets the module, so set it after every `begin()`.
In hold mode an awake host that only polls `modem.available()` sees nothing
until it sends a command.

MKRWAN_v2 has no call for a custom command, so a sketch writes it itself and
drains the reply before the library talks to the module again:

```cpp
#include <MKRWAN_v2.h>
#include <ArduinoLowPower.h>

LoRaModem modem;
volatile bool downlinkWaiting = false;

void onLoraIrq() { downlinkWaiting = true; }

void setup() {
  modem.begin(EU868);
  SerialLoRa.print("AT+DLHOLD=1\n");
  delay(100);
  while (SerialLoRa.available()) SerialLoRa.read();   // the "OK"
  LowPower.attachInterruptWakeup(LORA_IRQ, onLoraIrq, RISING);
  // join, …
}

void loop() {
  // send, then sleep; the RTC alarm or LORA_IRQ wakes the SAMD21
  LowPower.deepSleep(15 * 60 * 1000);
  if (downlinkWaiting) {
    downlinkWaiting = false;
    modem.getDataRate();          // any command delivers the held +EVT
    while (modem.available()) { /* modem.read() … */ }
  }
}
```

## Versions

`AT+VER?` reports `APP_VERSION` from
`Projects/B-L072Z-LRWAN1/Applications/LoRa/AT_Slave/LoRaWAN/App/inc/version.h`.
Upstream 1.3.1 is `01.03.00.00`; this fork counts its releases in the last byte
(`01.03.00.01`, …), tags them `v1.3.1-remus.N` and attaches the `.bin` to the
GitHub release.

| Version | Change |
| --- | --- |
| `01.03.00.01` | downlink hold mode, `AT+DLHOLD` |

## Upstream pull requests not merged

To review before taking any of them: #25 (data rate fix on 1.3.1), #27
(update of the 1.3.1 branch), #35 (compiler warnings, missing AT return states).

## License

The code keeps its original licenses: BSD-3-Clause (Semtech LoRaMac, ST HAL),
ST's SLA0044 for ST's application code (binaries for ST devices only, which the
module's STM32 is), GPL-2.0 for the Makefile.

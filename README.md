# MKR WAN 1310 module firmware (remuslazar fork)

Firmware for the Murata CMWX1ZZABZ-078 module (STM32L072 + SX1276) on the
Arduino MKR WAN 1300/1310: the AT-command LoRaWAN modem the SAMD21 talks to.
It is Arduino's [mkrwan1300-fw](https://github.com/arduino/mkrwan1300-fw),
derived from ST's I-CUBE-LRWAN AT_Slave example for the B-L072Z-LRWAN1 kit,
which carries the same module.

This fork exists to fix what upstream left open after its last change in 2021,
starting with downlinks lost while the SAMD21 sleeps
([MKRWAN#36](https://github.com/arduino-libraries/MKRWAN/issues/36),
[MKRWAN_v2#24](https://github.com/arduino-libraries/MKRWAN_v2/issues/24)).
It stays AT-compatible with the [MKRWAN_v2](https://github.com/arduino-libraries/MKRWAN_v2)
library, so sketches keep working.

## Branches

| Branch | Content |
| --- | --- |
| `remus-1.3.1` (default) | this fork's work, based on upstream `master-1.3.1` |
| `master-1.3.1` | upstream 1.3.1, the ST-based firmware MKRWAN_v2 expects |
| `master` | upstream 1.2.3, the older line for the MKRWAN library |
| `experiment-1.4.0` | upstream's abandoned LoRaMac-node import |

The upstream remote is `upstream`; `git fetch upstream` shows if it ever moves.

## Build

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

## Versions

`AT+VER?` reports `APP_VERSION` from
`Projects/B-L072Z-LRWAN1/Applications/LoRa/AT_Slave/LoRaWAN/App/inc/version.h`.
Upstream 1.3.1 is `01.03.00.00`; this fork counts its releases in the last byte
(`01.03.00.01`, …), tags them `v1.3.1-remus.N` and attaches the `.bin` to the
GitHub release.

## Upstream pull requests not merged

To review before taking any of them: #25 (data rate fix on 1.3.1), #27
(update of the 1.3.1 branch), #35 (compiler warnings, missing AT return states).

## License

The code keeps its original licenses: BSD-3-Clause (Semtech LoRaMac, ST HAL),
ST's SLA0044 for ST's application code (binaries for ST devices only, which the
module's STM32 is), GPL-2.0 for the Makefile.

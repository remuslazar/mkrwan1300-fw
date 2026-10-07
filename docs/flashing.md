# Build and flash the module firmware

A step-by-step guide for putting this fork's firmware on the LoRa module of an
Arduino MKR WAN 1310 (the 1300 takes the same image). You do not need a debugger
or any soldering: the board's own SAMD21 flashes the module over USB.

Nothing here can brick the board. The module's STM32 has a bootloader in ROM
that no flashing can overwrite, so Arduino's original firmware can always go
back on (see [Go back to Arduino's firmware](#go-back-to-arduinos-firmware)).

## What you need

- An MKR WAN 1310 with its antenna attached — the radio must never transmit
  without one.
- A micro-USB cable that carries data; many charge-only cables do not.
- The Arduino IDE 2, or PlatformIO (VS Code extension or `pio` CLI).
- The **MKRWAN_v2** library (Library Manager: "MKRWAN_v2", by Arduino). Its
  examples do the flashing.

## 1. Get the image

The image is `mlm32l07x01.bin`; the flasher sketch takes it as `fw.h`, the same
bytes as a C array.

**Download**: a GitHub release of this fork, when there is one, carries both
files.

**Or build it** (macOS or Linux, with PlatformIO installed):

```sh
git clone https://github.com/remuslazar/mkrwan1300-fw.git
cd mkrwan1300-fw
./build.sh
```

`build.sh` installs the pinned compiler on first use (GNU Arm Embedded gcc 7.2.1
from PlatformIO; on Apple Silicon it runs under Rosetta) and writes
`mlm32l07x01.bin` and `fw.h` into the repository root, printing the image's
SHA-256 at the end.

## 2. Flash it

### Route A: the standalone updater sketch (recommended)

The MKRWAN_v2 example `MKRWANFWUpdate_standalone` carries a firmware image in its
`fw.h` and writes it to the module. Give it this fork's `fw.h` instead.

**Arduino IDE**

1. *File → Examples → MKRWAN_v2 → MKRWANFWUpdate_standalone*, then
   *File → Save As…* to get your own copy of the sketch folder.
2. Replace `fw.h` in that folder with the `fw.h` from step 1.
3. Select *Arduino MKR WAN 1310* and its port, then upload.
4. Open the Serial Monitor at **115200** baud. The sketch waits for it, then
   prints the module's bootloader details, flashes, verifies, and starts the
   new firmware.

**PlatformIO**

1. New project, board `mkrwan1310`, framework Arduino; add
   `lib_deps = arduino-libraries/MKRWAN_v2` to `platformio.ini`.
2. Copy all files of the library's `examples/MKRWANFWUpdate_standalone` folder
   into `src/`, rename the `.ino` to `main.cpp` and add `#include <Arduino.h>`
   as its first line.
3. Replace `src/fw.h` with the `fw.h` from step 1.
4. `pio run -t upload`, then `pio device monitor -b 115200`.

### Route B: bridge sketch and stm32flash

For flashing the `.bin` from the command line, for example while developing:

1. Upload the MKRWAN_v2 example `FWUpdaterBridge`. It holds the module in its
   bootloader and relays the USB port to the module's UART (115200 baud, 8E1).
2. Install stm32flash (`brew install stm32flash`, or your distribution's
   package) and run, with the board's port:

   ```sh
   stm32flash -b 115200 -m 8e1 -w mlm32l07x01.bin -v -g 0x0 /dev/cu.usbmodem1101
   ```

   On Linux the port is `/dev/ttyACM0` or similar; on Windows `COM…`.

### Afterwards

Upload your real sketch to the SAMD21 again. The module keeps its firmware
across SAMD21 uploads; only the steps above change it.

## 3. Check the version

Upload the MKRWAN_v2 example `FirstConfiguration` and open the Serial Monitor:
it prints the module's firmware version. This fork's builds count up the last
part (`01.03.00.01` = 1.3.0.1 and on), Arduino's 1.3.1 shows `01.03.00.00`. The
raw command is `AT+VER=?`.

## Go back to Arduino's firmware

Upload the MKRWAN_v2 example `MKRWANFWUpdate_standalone` unmodified: its `fw.h`
is Arduino's own 1.3.1 image.

## When it does not work

- **No serial port appears**: try another cable; or double-tap the board's
  RESET button — the orange LED pulses and the SAMD21's bootloader port shows up,
  ready for an upload.
- **The updater cannot talk to the module** (no device ID, init errors): reset
  the board and open the Serial Monitor again; the module enters its bootloader
  on every run of the sketch.
- **The sketch hangs after upload**: it waits until the Serial Monitor is open.

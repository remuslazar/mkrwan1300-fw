#!/usr/bin/env bash
# Build the module firmware with the pinned toolchain: PlatformIO's
# toolchain-gccarmnoneeabi 1.70201.0 (GNU Arm Embedded 7-2017-q4, gcc 7.2.1),
# the same one PlatformIO's atmelsam platform uses for the SAMD21 side.
# It builds 1.3.1 without warnings; gcc 12.3 builds too, with 5 warnings.
# On Apple Silicon this toolchain is an x86_64 binary and runs under Rosetta.
#
# Output (from the Makefile): mlm32l07x01.{elf,hex,bin} and fw.h, the binary
# as a C array for the MKRWAN_v2 library's MKRWANFWUpdate_standalone example.
set -euo pipefail
cd "$(dirname "$0")"

VERSION=1.70201.0
PACKAGES="$HOME/.platformio/packages"

find_toolchain() {
  for dir in "$PACKAGES/toolchain-gccarmnoneeabi@$VERSION" "$PACKAGES/toolchain-gccarmnoneeabi"; do
    if grep -qs "\"version\": \"$VERSION\"" "$dir/package.json"; then
      echo "$dir/bin/arm-none-eabi-"
      return
    fi
  done
}

PREFIX=$(find_toolchain)
if [ -z "$PREFIX" ]; then
  pio pkg install --global --tool "platformio/toolchain-gccarmnoneeabi@$VERSION"
  PREFIX=$(find_toolchain)
fi

make CROSS_COMPILE="$PREFIX" -j"$(sysctl -n hw.ncpu 2>/dev/null || nproc)" "$@"
shasum -a 256 mlm32l07x01.bin

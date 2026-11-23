#!/bin/bash
#
# soak.sh: long games, WebAssembly vs native, compared after every call (opt-in; Wasm/parity.sh runs a short one).
#
#   Wasm/soak.sh [year:seedhex:turns[:rules[:player[:turnLength[:hawk]]]] ...]
#
# Builds the native CLI (gtnw-golden) and the WebAssembly engine, then plays each game in both at once through the
# same bridge (Wasm/parity/soak.mjs): every reply (events and state) and every turn's full saved game must match.
# Default games: 1789, 1914, 1962 and 2025, 330 weekly turns each (seeds and seats picked to last), and a 1962 hawk
# game with strikes and nuclear launches. Exits 1 on the first divergence, with its path.
#   SKIP_WASM_BUILD=1  reuse Wasm/dist/gtnw.wasm      WASM=<file>  soak another build (e.g. Wasm/dist/gtnw.opt.wasm)
#   WASM=native        two native processes instead (a baseline: anything that differs between two runs)
#
set -euo pipefail
cd "$(dirname "$0")/.."
TOOLCHAIN="${SWIFT_TOOLCHAIN:-/Volumes/Data/swift-toolchains/swift-6.4.2-RELEASE.xctoolchain}"
DERIVED="${GTNW_DERIVED_DATA:-/Volumes/Data/xcode/DerivedData-GTNW-wasm}"
xcrun --sdk macosx "$TOOLCHAIN/usr/bin/swift" build -c release --product gtnw-golden --scratch-path "$DERIVED/spm-release" -q
NATIVE="$(xcrun --sdk macosx "$TOOLCHAIN/usr/bin/swift" build -c release --product gtnw-golden --scratch-path "$DERIVED/spm-release" --show-bin-path)/gtnw-golden"
WASM="${WASM:-Wasm/dist/gtnw.wasm}"
if [ "$WASM" = Wasm/dist/gtnw.wasm ] && [ "${SKIP_WASM_BUILD:-0}" != 1 ]; then Wasm/build.sh release; fi
node Wasm/parity/soak.mjs "$WASM" "$NATIVE" . "$@"

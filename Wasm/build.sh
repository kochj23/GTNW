#!/bin/bash
#
# build.sh: build the GTNW engine as WebAssembly (GTNWWasm reactor) with the Swift SDK for WebAssembly.
#
#   Wasm/build.sh [debug|release]      → Wasm/dist/gtnw.wasm
#   OPT=1 Wasm/build.sh                 also → Wasm/dist/gtnw.opt.wasm (wasm-opt -Oz, names stripped: the one to ship)
#
# The link drops DWARF (--strip-debug) and keeps the name section, so a trap in gtnw.wasm still names its function.
# The core links FoundationEssentials, not Foundation (Package.swift); Documentation/WASM-PORT.md has the sizes.
#
# Needs the swift.org toolchain that matches the SDK (Xcode's toolchain cannot target WASI) and the SDK itself.
# Defaults are the /Volumes/Data installs; override with SWIFT_TOOLCHAIN, SWIFT_SDKS_PATH, SWIFT_SDK, WASM_OPT.
# Install (once):
#   pkgutil --expand-full swift-6.4.2-RELEASE-osx.pkg x && mv x/swift-6.4.2-RELEASE-osx-package.pkg/Payload \
#     /Volumes/Data/swift-toolchains/swift-6.4.2-RELEASE.xctoolchain
#   swift sdk install https://download.swift.org/swift-6.4.2-release/wasm-sdk/swift-6.4.2-RELEASE/swift-6.4.2-RELEASE_wasm.artifactbundle.tar.gz \
#     --checksum 83baca83553f8c443cda7b84800912e6e709c3acd2e7ebf277794ca5836c0da5 --swift-sdks-path /Volumes/Data/swift-sdks
#
set -euo pipefail
cd "$(dirname "$0")/.."
CONFIG="${1:-release}"
TOOLCHAIN="${SWIFT_TOOLCHAIN:-/Volumes/Data/swift-toolchains/swift-6.4.2-RELEASE.xctoolchain}"
SDKS="${SWIFT_SDKS_PATH:-/Volumes/Data/swift-sdks}"
SDK="${SWIFT_SDK:-swift-6.4.2-RELEASE_wasm}"
SCRATCH="${SWIFT_SCRATCH:-/Volumes/Data/xcode/DerivedData-GTNW-wasm/spm-wasm}"
WASM_OPT="${WASM_OPT:-$(command -v wasm-opt || echo /Volumes/Data/tools/binaryen/bin/wasm-opt)}"

"$TOOLCHAIN/usr/bin/swift" build -c "$CONFIG" --product GTNWWasm --swift-sdk "$SDK" --swift-sdks-path "$SDKS" \
  --scratch-path "$SCRATCH" -Xswiftc -Xclang-linker -Xswiftc -mexec-model=reactor \
  -Xlinker --export=_initialize -Xlinker --strip-debug

BIN="$("$TOOLCHAIN/usr/bin/swift" build -c "$CONFIG" --product GTNWWasm --swift-sdk "$SDK" --swift-sdks-path "$SDKS" \
  --scratch-path "$SCRATCH" --show-bin-path)/GTNWWasm.wasm"
mkdir -p Wasm/dist
rm -f Wasm/dist/gtnw.opt.wasm
cp "$BIN" Wasm/dist/gtnw.wasm
if [ "${OPT:-0}" = 1 ]; then
  [ -x "$WASM_OPT" ] || { echo "wasm-opt not found (WASM_OPT=)" >&2; exit 1; }
  "$WASM_OPT" -Oz --enable-bulk-memory --enable-sign-ext --enable-nontrapping-float-to-int --enable-mutable-globals \
    --strip-debug Wasm/dist/gtnw.wasm -o Wasm/dist/gtnw.opt.wasm
fi
for f in Wasm/dist/gtnw.wasm Wasm/dist/gtnw.opt.wasm; do
  [ -f "$f" ] || continue
  raw=$(wc -c < "$f" | tr -d ' ')
  br=$(brotli -c -q 11 "$f" | wc -c | tr -d ' ')
  echo "$f: $raw bytes raw, $br bytes brotli"
done

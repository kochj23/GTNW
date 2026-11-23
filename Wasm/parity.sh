#!/bin/bash
#
# parity.sh: the WebAssembly engine plays the golden games exactly as the native app does.
#
#   Wasm/parity.sh [fixtures dir]
#
# Plays the golden games (1789, 1962, 2025; 12 turns each, scripted orders) three ways and compares every turn's
# snapshot, the opening board and the RNG vectors with the fixtures the app exported (GTNWTests/GoldenExportTests,
# Documentation/GOLDEN.md):
#   1. GTNWCore natively (swift build: gtnw-golden)
#   2. GTNWCore as WebAssembly under Node (Wasm/build.sh, Wasm/parity/play-wasm.mjs)
# Exits 1 on the first game that differs. The fixtures default to NovaGames' copy; FRESH=1 exports new ones from the
# app first (xcodebuild, one test class, a few minutes). SKIP_WASM_BUILD=1 reuses Wasm/dist/gtnw.wasm.
# No network: the toolchain, the SDK and Node must be installed (Wasm/build.sh says how).
#
set -euo pipefail
cd "$(dirname "$0")/.."
FIXTURES="${1:-${GTNW_GOLDEN_FIXTURES:-/Volumes/Data/xcode/NovaGames/games/gtnw-lite/tests/fixtures/gtnw-golden}}"
TOOLCHAIN="${SWIFT_TOOLCHAIN:-/Volumes/Data/swift-toolchains/swift-6.4.2-RELEASE.xctoolchain}"
DERIVED="${GTNW_DERIVED_DATA:-/Volumes/Data/xcode/DerivedData-GTNW-wasm}"
OUT="$(mktemp -d)"
trap 'rm -rf "$OUT"' EXIT

if [ "${FRESH:-0}" = 1 ]; then
  FIXTURES="$OUT/fixtures"; mkdir -p "$FIXTURES"
  TEST_RUNNER_GTNW_EXPORT_GOLDEN="$FIXTURES" xcodebuild test -project GTNW.xcodeproj -scheme GTNW_macOS \
    -derivedDataPath "$DERIVED" -destination 'platform=macOS' -only-testing:GTNWTests/GoldenExportIntegrationTests -quiet
fi
[ -f "$FIXTURES/manifest.json" ] || { echo "no fixtures at $FIXTURES" >&2; exit 2; }

echo "== native (GTNWCore, swift build)"
xcrun --sdk macosx "$TOOLCHAIN/usr/bin/swift" build -c release --product gtnw-golden --scratch-path "$DERIVED/spm-release" -q
"$(xcrun --sdk macosx "$TOOLCHAIN/usr/bin/swift" build -c release --product gtnw-golden --scratch-path "$DERIVED/spm-release" --show-bin-path)/gtnw-golden" . > "$OUT/native.json"
node Wasm/parity/compare.mjs "$FIXTURES" "$OUT/native.json" native

echo "== WebAssembly (GTNWWasm under Node)"
[ "${SKIP_WASM_BUILD:-0}" = 1 ] || Wasm/build.sh release
node Wasm/parity/play-wasm.mjs Wasm/dist/gtnw.wasm . > "$OUT/wasm.json"
node Wasm/parity/compare.mjs "$FIXTURES" "$OUT/wasm.json" wasm

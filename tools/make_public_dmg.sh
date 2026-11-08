#!/usr/bin/env bash
# Build the PUBLIC GTNW disk image: the full game with no Games DB, no core3 hand-off and no Nova banner
# (PUBLIC_EDITION), signed with Developer ID, notarized by Apple and stapled, so it opens on any Mac with no warning.
#
#   tools/make_public_dmg.sh            release: Developer ID + notarization (needs Xcode signed in to the team)
#   tools/make_public_dmg.sh --adhoc    local test of the whole pipeline; the DMG is NOT for distribution
#
# Notarization uses the Xcode account by default (exportArchive destination=upload). If NOTARY_PROFILE is set
# (xcrun notarytool store-credentials <name>), the DMG itself is notarized and stapled too.
# Output: $OUT/GTNW-<version>.dmg (default /Volumes/Data/xcode/binaries) and a copy in /Volumes/NAS/binaries.
set -euo pipefail

ADHOC=0
[[ "${1:-}" == "--adhoc" ]] && ADHOC=1
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TEAM="${TEAM:-QRRCB8HB3W}"
OUT="${OUT:-/Volumes/Data/xcode/binaries}"
# Build on the internal disk: external volumes ignore ownership and the archive's chown step fails there.
WORK="$(mktemp -d "${TMPDIR:-/tmp}/gtnw-public.XXXXXX")"
log() { echo "[make_public_dmg] $*" >&2; }

cd "$ROOT"
VERSION="$(xcodebuild -project GTNW.xcodeproj -scheme GTNW_macOS -showBuildSettings 2>/dev/null \
           | awk -F' = ' '/ MARKETING_VERSION /{print $2; exit}')"
[[ -n "$VERSION" ]] || { log "could not read MARKETING_VERSION"; exit 1; }
NAME="GTNW-$VERSION"; [[ $ADHOC == 1 ]] && NAME="$NAME-adhoc-TEST"
log "version $VERSION, work dir $WORK"

log "archiving the public edition"
xcodebuild archive -project GTNW.xcodeproj -scheme GTNW_macOS -configuration Release \
  -destination 'generic/platform=macOS' -derivedDataPath "$WORK/dd" -archivePath "$WORK/GTNW.xcarchive" \
  'SWIFT_ACTIVE_COMPILATION_CONDITIONS=$(inherited) PUBLIC_EDITION' EXCLUDED_SOURCE_FILE_NAMES=games-pg-ca.crt \
  -allowProvisioningUpdates > "$WORK/archive.log" 2>&1 || { tail -20 "$WORK/archive.log"; exit 1; }
if find "$WORK/GTNW.xcarchive" -name 'games-pg-ca.crt' | grep -q .; then
  log "FAIL: the Games DB CA is still in the bundle"; exit 1
fi

mkdir -p "$WORK/app"
if [[ $ADHOC == 1 ]]; then
  log "ad hoc signing (test only)"
  ditto "$WORK/GTNW.xcarchive/Products/Applications/GTNW.app" "$WORK/app/GTNW.app"
  pp="$WORK/app/GTNW.app/Contents/embedded.provisionprofile"
  [[ -f "$pp" ]] && mv "$pp" "$WORK/embedded.provisionprofile.removed"
  codesign --force --deep -s - "$WORK/app/GTNW.app"
else
  log "exporting with Developer ID and submitting to Apple's notary service"
  cat > "$WORK/export.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>method</key><string>developer-id</string>
<key>signingStyle</key><string>automatic</string>
<key>teamID</key><string>$TEAM</string>
<key>destination</key><string>upload</string>
</dict></plist>
EOF
  xcodebuild -exportArchive -archivePath "$WORK/GTNW.xcarchive" -exportOptionsPlist "$WORK/export.plist" \
    -exportPath "$WORK/upload" -allowProvisioningUpdates > "$WORK/export.log" 2>&1 \
    || { grep -E 'error' "$WORK/export.log" | head -10; log "export failed: is Xcode signed in (Settings > Accounts)?"; exit 1; }
  log "waiting for notarization (usually a few minutes)"
  for i in $(seq 1 90); do
    if xcodebuild -exportNotarizedApp -archivePath "$WORK/GTNW.xcarchive" -exportPath "$WORK/app" > "$WORK/notary.log" 2>&1; then
      break
    fi
    [[ $i == 90 ]] && { tail -5 "$WORK/notary.log"; log "notarization did not finish in 45 minutes"; exit 1; }
    sleep 30
  done
  xcrun stapler validate "$WORK/app/GTNW.app" >/dev/null || { log "FAIL: no stapled ticket on the app"; exit 1; }
fi

log "building the disk image"
mkdir -p "$WORK/dmg"
ditto "$WORK/app/GTNW.app" "$WORK/dmg/GTNW.app"
ln -s /Applications "$WORK/dmg/Applications"
cat > "$WORK/dmg/Read Me.txt" <<EOF
GTNW $VERSION

Drag GTNW to Applications, then open it from there.

AI is optional. GTNW runs fine with no AI at all. To let an AI play the other countries and comment on your
presidency, pick a backend in GTNW > Settings: Ollama or MLX on this Mac (free, private), or your own API key for
OpenAI, Google, Azure, AWS or IBM. Keys are kept in your Mac's keychain.

Requires macOS 13 or later. For ages 17 and up: GTNW simulates nuclear war, political violence and historical
atrocities. It shows consequences and does not glorify war.
EOF
hdiutil create -volname "GTNW $VERSION" -srcfolder "$WORK/dmg" -format UDZO -ov "$WORK/$NAME.dmg" >/dev/null

if [[ $ADHOC == 0 ]]; then
  ID="$(security find-identity -v -p codesigning | awk -F'"' '/Developer ID Application/{print $2; exit}')"
  [[ -n "$ID" ]] || { log "FAIL: no Developer ID Application identity to sign the DMG"; exit 1; }
  codesign --force -s "$ID" --timestamp "$WORK/$NAME.dmg"
  if [[ -n "${NOTARY_PROFILE:-}" ]]; then
    xcrun notarytool submit "$WORK/$NAME.dmg" --keychain-profile "$NOTARY_PROFILE" --wait
    xcrun stapler staple "$WORK/$NAME.dmg"
  fi
fi

log "verifying the image"
MNT="$(mktemp -d "$WORK/mnt.XXXXXX")"
hdiutil attach -nobrowse -readonly -mountpoint "$MNT" "$WORK/$NAME.dmg" >/dev/null
trap 'hdiutil detach -quiet "$MNT" 2>/dev/null || true' EXIT
[[ -d "$MNT/GTNW.app" && -L "$MNT/Applications" ]] || { log "FAIL: image layout"; exit 1; }
codesign --verify --deep --strict "$MNT/GTNW.app"
if find "$MNT/GTNW.app" -name 'games-pg-ca.crt' | grep -q .; then log "FAIL: CA in the image"; exit 1; fi
if [[ $ADHOC == 0 ]]; then
  spctl -a -t exec -vv "$MNT/GTNW.app" 2>&1 | grep -q "Notarized Developer ID" \
    || { spctl -a -t exec -vv "$MNT/GTNW.app"; log "FAIL: Gatekeeper does not accept the app"; exit 1; }
fi
"$ROOT/tools/launch_smoke.sh" "$MNT/GTNW.app" >&2

mkdir -p "$OUT"
cp "$WORK/$NAME.dmg" "$OUT/"
[[ -d /Volumes/NAS/binaries ]] && cp "$WORK/$NAME.dmg" /Volumes/NAS/binaries/
shasum -a 256 "$OUT/$NAME.dmg"
log "done: $OUT/$NAME.dmg"

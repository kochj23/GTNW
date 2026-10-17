#!/bin/zsh
# Frame smoke test: launch a built GTNW.app hidden in the background (never
# activated, no focus steal), confirm it survives startup, then let it quit.
#   tools/launch_smoke.sh [/path/to/GTNW.app]
# The app's --launch-smoke flag hides its windows, skips the API server and
# exits 0 after ~2.5s. If it is somehow still alive after 10s it is killed by PID
# (never `pkill` — that would also hit a copy you are playing).
set -u
APP="${1:-/Applications/GTNW.app}"
BIN="$APP/Contents/MacOS/GTNW"
[[ -x "$BIN" ]] || { echo "FAIL: no binary at $BIN"; exit 2; }

open -g -j -n "$APP" --args --launch-smoke -ApplePersistenceIgnoreState YES || { echo "FAIL: open"; exit 1; }
sleep 1.5
PID=$(pgrep -nf "^$BIN --launch-smoke" || true)
[[ -n "$PID" ]] || { echo "FAIL: app not running 1.5s after launch (crashed on startup?)"; exit 1; }
echo "alive after 1.5s (pid $PID)"
for _ in {1..100}; do kill -0 "$PID" 2>/dev/null || { echo "PASS: launched, reached run loop, exited on its own"; exit 0; }; sleep 0.1; done
kill "$PID" 2>/dev/null
echo "FAIL: did not exit on its own within 10s"; exit 1

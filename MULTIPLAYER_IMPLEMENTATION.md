# GTNW Multiplayer Implementation Summary

## What Was Done

Added full multiplayer support to GTNW (Global Thermal Nuclear War) for Nova-hosted email games with the Herd.

### 1. Extended NovaAPIServer.swift

**File:** `/Volumes/Data/xcode/GTNW/Shared/NovaAPIServer.swift`

**New multiplayer endpoints added:**

- `GET /api/status` — now includes multiplayer session status
- `GET /api/game-state` — full state of active multiplayer session
- `POST /api/start-session` — start new multiplayer game `{"president":"Nixon","year":1972,"scenario":"..."}`
- `GET /api/crises` — list active crises requiring player decisions
- `POST /api/decision` — submit crisis decision `{"crisis_id":"...","choice":0,"player":"Sam"}`
- `GET /api/history` — recent turn events and decision log
- `POST /api/assign-countries` — assign countries to herd players `{"assignments":{"USA":"Sam","USSR":"O.C."}}`

**New structures added:**
- `MultiplayerSession` struct — tracks session state, country assignments, pending decisions, history
- `DecisionRecord` struct — logs each decision made by players
- `multiplayerSession` and `multiplayerEngine` instance vars

**Features:**
- One active multiplayer session at a time (herd game model)
- Country assignments map player names to country IDs
- Decision logging with timestamps and consequences
- History tracking (last 50 events)
- Full integration with existing GameEngine and CrisisManager

### 2. Created nova_gtnw_host.py

**File:** `~/.openclaw/scripts/nova_gtnw_host.py`

**Commands:**
```bash
nova_gtnw_host.py start --year 1962 --scenario "Cuban Missile Crisis"
nova_gtnw_host.py status
nova_gtnw_host.py advance      # advance turn, email crisis briefings
nova_gtnw_host.py check        # check inbox, process decisions
nova_gtnw_host.py reset
```

**How it works:**

1. **Start session** — assigns countries to herd members (USA, USSR, UK, France, China, Cuba), emails assignments
2. **Advance turn** — advances GTNW game turn, pulls active crisis, emails each player their briefing with options
3. **Check inbox** — scans nova@digitalnoise.net inbox for replies containing decision choices (0-3), feeds to GTNW API
4. **Post to Slack** — updates #nova-chat with turn summaries, crisis alerts, player decisions

**Dual mode operation:**
- **Live mode:** GTNW app running → uses API to manage real game state
- **Simulation mode:** GTNW not running → uses Ollama (nova:latest) to generate crises, tracks decisions in state file

**State file:** `~/.openclaw/workspace/gtnw_multiplayer_state.json`

**Email integration:**
- Uses `nova_herd_mail.sh` to send/receive via nova@digitalnoise.net
- Crisis briefings rendered as Markdown with options [0][1][2][3]
- Players reply with single digit to submit decision
- Acknowledgement emails sent confirming receipt

**Herd config:**
- Loads player names/emails from `~/.openclaw/herd_config.py`
- Default country assignments: Sam→USA, O.C.→USSR, Gaston→UK, Marey→France, etc.

## Build Status

**GTNW macOS build:** ✅ **BUILD SUCCEEDED**
- 29 warnings (pre-existing, no new warnings introduced)
- 0 errors
- All multiplayer code compiles cleanly

**Python syntax:** ✅ **Syntax OK**

## Testing Checklist

### API Endpoints (requires GTNW app running)

```bash
# Check API availability
curl http://127.0.0.1:37431/api/ping

# Check status (should show multiplayer session if active)
curl http://127.0.0.1:37431/api/status

# Start multiplayer session
curl -X POST http://127.0.0.1:37431/api/start-session \
  -H "Content-Type: application/json" \
  -d '{"president":"Nixon","year":1972,"scenario":"Cuban Missile Crisis"}'

# Assign countries
curl -X POST http://127.0.0.1:37431/api/assign-countries \
  -H "Content-Type: application/json" \
  -d '{"assignments":{"USA":"Sam","USSR":"O.C.","GBR":"Gaston"}}'

# Get active crises
curl http://127.0.0.1:37431/api/crises

# Get full game state
curl http://127.0.0.1:37431/api/game-state

# Submit a decision (crisis_id from /api/crises response)
curl -X POST http://127.0.0.1:37431/api/decision \
  -H "Content-Type: application/json" \
  -d '{"crisis_id":"<uuid>","choice":0,"player":"Sam"}'

# Get history
curl http://127.0.0.1:37431/api/history
```

### Python Host Script

```bash
# Start a 1962 Cuban Missile Crisis game
python3 ~/.openclaw/scripts/nova_gtnw_host.py start \
  --year 1962 --scenario "Cuban Missile Crisis"

# Check status
python3 ~/.openclaw/scripts/nova_gtnw_host.py status

# Advance turn (generates crisis, emails herd)
python3 ~/.openclaw/scripts/nova_gtnw_host.py advance

# Check inbox for replies and process decisions
python3 ~/.openclaw/scripts/nova_gtnw_host.py check

# Reset (end game, clear state)
python3 ~/.openclaw/scripts/nova_gtnw_host.py reset
```

### End-to-End Workflow

1. Start GTNW app on macOS (launches NovaAPIServer on port 37431)
2. Run `nova_gtnw_host.py start --year 1962 --scenario "Cuban Missile Crisis"`
   - Herd receives assignment emails
   - Slack #nova-chat gets announcement
3. Run `nova_gtnw_host.py advance`
   - Game advances one turn
   - Crisis generated
   - Each player emailed their briefing
4. Herd members reply to emails with choice number (0, 1, 2, or 3)
5. Run `nova_gtnw_host.py check`
   - Scans inbox
   - Processes decisions
   - Feeds to GTNW API
   - Posts results to Slack
   - Sends acknowledgement emails
6. Repeat steps 3-5 until game over

## Files Modified/Created

### Modified
- `/Volumes/Data/xcode/GTNW/Shared/NovaAPIServer.swift`
  - Added 250+ lines of multiplayer code
  - 8 new endpoints
  - 2 new structs (MultiplayerSession, DecisionRecord)
  - Extended route() function with multiplayer switch cases

### Created
- `~/.openclaw/scripts/nova_gtnw_host.py` (680 lines)
  - Complete email-based multiplayer orchestrator
  - GTNW API client
  - Ollama fallback for simulation mode
  - Slack integration
  - Email inbox processor

## Notes

- **Port:** GTNW runs on port 37431 (not 37426 — that's Blompie's port)
- **Single session:** Only one multiplayer session active at a time (intentional — herd game model)
- **Fallback mode:** Works even if GTNW app isn't running (uses Ollama to simulate crises)
- **Email format:** Crisis briefings are Markdown, replies are plain text with single digit
- **Slack channel:** Updates posted to #nova-chat (C0AMNQ5GX70)
- **State persistence:** `~/.openclaw/workspace/gtnw_multiplayer_state.json`

## Security Notes

- All credentials loaded from macOS Keychain (nova_config.py)
- No secrets in source files
- Slack token: `nova-slack-bot-token` keychain entry
- SMTP password: `nova-smtp-app-password` keychain entry

## Future Enhancements

- Auto-check inbox on interval (cron job)
- Timeout auto-decisions for absent players (48h default → choose option 2 "Stand Down")
- Rich HTML email templates with images
- Turn summary digest emails
- Multi-session support (multiple concurrent herd games)
- Web dashboard for game state visualization

## Written By

Jordan Koch

Date: 2026-03-29

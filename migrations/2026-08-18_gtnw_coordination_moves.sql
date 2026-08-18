-- GTNW live-session PvP over the Nova coordination bus
-- ---------------------------------------------------------------------------
-- Target DB: nova_ops  (host=localhost user=kochj)
-- Table:     claude_coordination  (existing cross-instance message bus)
--
-- GTNW parks a MoveRequest for a live Claude Code session, which answers by
-- writing a MoveResponse back onto the same row. GTNW polls for the answer and
-- falls back to rule-based AI if none arrives before its timeout.
--
-- Existing columns: id, ts, from_instance, topic, message, status
-- This migration adds the structured game/turn/country key + response payload
-- so a session can find open GTNW moves and answer them. Idempotent.
-- ---------------------------------------------------------------------------

ALTER TABLE claude_coordination ADD COLUMN IF NOT EXISTS game_key    text;
ALTER TABLE claude_coordination ADD COLUMN IF NOT EXISTS turn        integer;
ALTER TABLE claude_coordination ADD COLUMN IF NOT EXISTS country_id  text;
ALTER TABLE claude_coordination ADD COLUMN IF NOT EXISTS response    jsonb;
ALTER TABLE claude_coordination ADD COLUMN IF NOT EXISTS answered_at timestamptz;

-- Fast lookup of the single row for a given move (game/turn/country).
CREATE UNIQUE INDEX IF NOT EXISTS idx_coord_gtnw_move
    ON claude_coordination (game_key, turn, country_id)
    WHERE topic = 'gtnw-move';

-- Fast scan for OPEN GTNW moves awaiting a live session.
CREATE INDEX IF NOT EXISTS idx_coord_gtnw_open
    ON claude_coordination (topic, status)
    WHERE topic = 'gtnw-move' AND status = 'open';

-- Row contract for a GTNW move
-- ---------------------------------------------------------------------------
--   topic        = 'gtnw-move'
--   from_instance= requesting game instance (e.g. 'gtnw-app')
--   game_key     = MoveRequest.gameId          (e.g. 'USA-1983')
--   turn         = MoveRequest.turn
--   country_id   = MoveRequest.countryId       (e.g. 'RUS')
--   message      = MoveRequest JSON            (full request payload)
--   status       = 'open'  -> awaiting a live session
--                  'answered' -> response is populated
--   response     = MoveResponse JSON  {"action","target","params","rationale"}
--   answered_at  = when the session answered
--
-- A live Claude Code session answers with, e.g.:
--   UPDATE claude_coordination
--      SET response = '{"action":"DECLARE_WAR","target":"CHN"}'::jsonb,
--          status = 'answered', answered_at = now()
--    WHERE topic='gtnw-move' AND game_key='USA-1983' AND turn=12 AND country_id='RUS';
-- ---------------------------------------------------------------------------

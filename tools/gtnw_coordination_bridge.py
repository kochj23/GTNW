#!/usr/bin/env python3
"""
gtnw_coordination_bridge.py — thin HTTP bridge for GTNW live-session PvP.

GTNW (the macOS app) talks HTTP to this bridge on loopback; the bridge owns the
single Postgres write/read against nova_ops.claude_coordination. This keeps GTNW
free of a heavy pinned Postgres SPM dependency.

Endpoints
---------
POST /gtnw/move            body: MoveRequest JSON {gameId,countryId,turn,...}
                           -> parks the move as an OPEN row for a live session.
GET  /gtnw/move/<key>      key = "<gameId>/<turn>/<countryId>"
                           -> 200 + MoveResponse JSON once answered, else 204.

A live Claude Code session answers by updating the row (see the migration
migrations/2026-08-18_gtnw_coordination_moves.sql), or via:
POST /gtnw/answer          body: {"game_key","turn","country_id","response":{...}}

Run:  DATABASE_URL=postgres://kochj@localhost/nova_ops python3 gtnw_coordination_bridge.py
      (defaults to host=localhost dbname=nova_ops user=kochj if unset)

NOTE: This is the follow-up helper Jordan must stand up for END-TO-END live PvP.
Until it (or an equivalent gateway route) runs, GTNW's live-session calls simply
time out and fall back to rule-based AI — harmless.
"""

import json
import os
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

import psycopg2  # pip install psycopg2-binary

DSN = os.environ.get("DATABASE_URL", "host=localhost dbname=nova_ops user=kochj")
PORT = int(os.environ.get("GTNW_BRIDGE_PORT", "18793"))


def connect():
    return psycopg2.connect(DSN)


class Handler(BaseHTTPRequestHandler):
    def _send(self, code, payload=None):
        self.send_response(code)
        if payload is not None:
            body = json.dumps(payload).encode()
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)
        else:
            self.send_header("Content-Length", "0")
            self.end_headers()

    def _body(self):
        n = int(self.headers.get("Content-Length", 0))
        return json.loads(self.rfile.read(n) or b"{}")

    def do_POST(self):
        if self.path == "/gtnw/move":
            req = self._body()
            key = f'{req["gameId"]}/{req["turn"]}/{req["countryId"]}'
            with connect() as conn, conn.cursor() as cur:
                cur.execute(
                    """
                    INSERT INTO claude_coordination
                        (from_instance, topic, message, status, game_key, turn, country_id)
                    VALUES ('gtnw-app', 'gtnw-move', %s, 'open', %s, %s, %s)
                    ON CONFLICT (game_key, turn, country_id)
                        WHERE topic = 'gtnw-move'
                    DO UPDATE SET message = EXCLUDED.message, status = 'open',
                                 response = NULL, answered_at = NULL, ts = now()
                    """,
                    (json.dumps(req), req["gameId"], req["turn"], req["countryId"]),
                )
            return self._send(202, {"parked": key})

        if self.path == "/gtnw/answer":
            a = self._body()
            with connect() as conn, conn.cursor() as cur:
                cur.execute(
                    """
                    UPDATE claude_coordination
                       SET response = %s::jsonb, status = 'answered', answered_at = now()
                     WHERE topic = 'gtnw-move' AND game_key = %s AND turn = %s AND country_id = %s
                    """,
                    (json.dumps(a["response"]), a["game_key"], a["turn"], a["country_id"]),
                )
            return self._send(200, {"answered": True})

        self._send(404, {"error": "not found"})

    def do_GET(self):
        if self.path.startswith("/gtnw/move/"):
            key = self.path[len("/gtnw/move/"):]
            try:
                game_key, turn, country_id = key.rsplit("/", 2)
            except ValueError:
                return self._send(400, {"error": "bad key"})
            with connect() as conn, conn.cursor() as cur:
                cur.execute(
                    """
                    SELECT response FROM claude_coordination
                     WHERE topic = 'gtnw-move' AND game_key = %s AND turn = %s
                       AND country_id = %s AND status = 'answered'
                    """,
                    (game_key, turn, country_id),
                )
                row = cur.fetchone()
            if row and row[0]:
                return self._send(200, row[0])
            return self._send(204)  # still pending

        self._send(404, {"error": "not found"})

    def log_message(self, *args):
        pass  # quiet


if __name__ == "__main__":
    print(f"GTNW coordination bridge on 127.0.0.1:{PORT} (DSN: {DSN})")
    ThreadingHTTPServer(("127.0.0.1", PORT), Handler).serve_forever()

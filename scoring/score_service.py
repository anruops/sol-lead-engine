"""
RECON score service: the rubric as a tiny local HTTP service n8n calls.

  POST /score    body = one lead (a Score Batch row)  -> the scored fields
  GET  /health   -> {"ok": true, "rubric_version": "..."}

Python standard library only (no installs).

Settings (environment variables, all optional):
  RECON_SCORE_HOST  default 127.0.0.1 (this machine only). Use 0.0.0.0 only
                    inside a private Docker network, never on an open server.
  RECON_SCORE_PORT  default 8765
  RECON_SCORE_KEY   if set, every /score call must send the header
                    X-Score-Key with the same value (use it whenever the
                    service is reachable by anything other than localhost)

Run under a process manager next to n8n, e.g.
  pm2 start score_service.py --interpreter py --name recon-score
"""
from __future__ import annotations

import hmac
import json
import os
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

from recon_rubric import RUBRIC_VERSION, score_lead

HOST = os.environ.get("RECON_SCORE_HOST", "127.0.0.1")
PORT = int(os.environ.get("RECON_SCORE_PORT", "8765"))
KEY = os.environ.get("RECON_SCORE_KEY", "")
MAX_BODY = 1_000_000  # 1 MB is far more than one lead needs


class Handler(BaseHTTPRequestHandler):
    def _send(self, status: int, payload: dict) -> None:
        body = json.dumps(payload).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self) -> None:
        if self.path == "/health":
            self._send(200, {"ok": True, "rubric_version": RUBRIC_VERSION})
        else:
            self._send(404, {"error": "not found"})

    def do_POST(self) -> None:
        if self.path != "/score":
            self._send(404, {"error": "not found"})
            return
        if KEY and not hmac.compare_digest(self.headers.get("X-Score-Key", ""), KEY):
            self._send(401, {"error": "missing or wrong X-Score-Key"})
            return
        length = int(self.headers.get("Content-Length") or 0)
        if length <= 0 or length > MAX_BODY:
            self._send(400, {"error": "send one lead as a JSON body"})
            return
        try:
            lead = json.loads(self.rfile.read(length))
            if not isinstance(lead, dict) or not lead.get("lead_key"):
                raise ValueError("lead_key missing")
            self._send(200, score_lead(lead))
        except (ValueError, TypeError, KeyError) as exc:
            self._send(400, {"error": f"could not score this lead: {exc}"})

    def log_message(self, fmt: str, *args) -> None:  # keep pm2 logs short
        print(f"{self.command} {self.path} -> {args[1] if len(args) > 1 else ''}")


if __name__ == "__main__":
    print(f"RECON score service {RUBRIC_VERSION} on http://{HOST}:{PORT}"
          + (" (key required)" if KEY else ""))
    ThreadingHTTPServer((HOST, PORT), Handler).serve_forever()

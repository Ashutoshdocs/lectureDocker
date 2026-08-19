#!/usr/bin/env python3
"""
Two-tier swarm demo — the WEB tier (runs on the manager node).

Serves a browser form that writes rows into a Postgres database living on the
WORKER node, reached by the service name `db` over the overlay network.
Also exposes GET /api/messages (JSON) for curl-based verification.
"""
import os, time, html, json, socket
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs
import psycopg2

DB = dict(
    host=os.getenv("DB_HOST", "db"),
    dbname=os.getenv("DB_NAME", "appdb"),
    user=os.getenv("DB_USER", "appuser"),
    password=os.getenv("DB_PASSWORD", "apppass"),
)
WEB_HOST = socket.gethostname()          # this container's id — shown in the UI
LISTEN_PORT = int(os.getenv("PORT", "80"))


def connect(retries=30, delay=2):
    """Connect to the worker's Postgres, retrying while it warms up."""
    last = None
    for i in range(retries):
        try:
            return psycopg2.connect(connect_timeout=3, **DB)
        except Exception as e:            # noqa: BLE001
            last = e
            print(f"[web] db not ready ({i+1}/{retries}): {e}", flush=True)
            time.sleep(delay)
    raise last


def init_db():
    conn = connect()
    conn.autocommit = True
    with conn.cursor() as cur:
        cur.execute(
            """
            CREATE TABLE IF NOT EXISTS messages (
                id         SERIAL PRIMARY KEY,
                name       TEXT NOT NULL,
                message    TEXT NOT NULL,
                web_host   TEXT,
                created_at TIMESTAMPTZ NOT NULL DEFAULT now()
            );
            """
        )
    conn.close()
    print("[web] schema ready", flush=True)


def fetch_rows():
    conn = connect(retries=3, delay=1)
    with conn.cursor() as cur:
        cur.execute(
            "SELECT id, name, message, web_host, created_at "
            "FROM messages ORDER BY id DESC LIMIT 200;"
        )
        rows = cur.fetchall()
    conn.close()
    return rows


def insert_row(name, message):
    conn = connect(retries=3, delay=1)
    conn.autocommit = True
    with conn.cursor() as cur:
        cur.execute(
            "INSERT INTO messages (name, message, web_host) VALUES (%s, %s, %s);",
            (name[:120], message[:500], WEB_HOST),
        )
    conn.close()


# --------------------------------------------------------------------------- UI
PAGE = r"""<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Overlay Ledger · web@manager → db@worker</title>
<style>
  :root{
    --bg:#0b1020; --panel:#121a32; --panel-2:#0f1730; --line:#26324f;
    --amber:#f6b13c; --amber-soft:#ffd27a; --emerald:#4ade80; --sky:#61dafb;
    --text:#e7ecf7; --dim:#8695b8;
    --mono:ui-monospace,"JetBrains Mono","SF Mono","Cascadia Code",Menlo,Consolas,monospace;
    --sans:system-ui,-apple-system,"Segoe UI",Roboto,sans-serif;
  }
  *{box-sizing:border-box}
  body{
    margin:0; font-family:var(--sans); color:var(--text);
    background:
      radial-gradient(800px 480px at 8% -8%,rgba(246,177,60,.10),transparent 60%),
      radial-gradient(700px 520px at 108% 6%,rgba(97,218,251,.10),transparent 55%),
      linear-gradient(180deg,#080c18,#0b1020);
    background-attachment:fixed; padding:32px 20px 60px;
  }
  .wrap{max-width:860px;margin:0 auto}
  .eyebrow{font-family:var(--mono);font-size:12px;letter-spacing:.22em;
    text-transform:uppercase;color:var(--dim)}
  .eyebrow b{color:var(--amber);font-weight:600;letter-spacing:.14em}
  h1{font-family:var(--mono);font-weight:700;line-height:1.02;margin:.35em 0 .1em;
    font-size:clamp(30px,6vw,46px);letter-spacing:-.02em;
    background:linear-gradient(115deg,#fff,var(--amber-soft) 60%,var(--amber));
    -webkit-background-clip:text;background-clip:text;color:transparent}
  .lede{color:var(--dim);font-size:15px;max-width:60ch;line-height:1.5}

  /* pipeline signature */
  .pipe{display:flex;align-items:stretch;gap:0;margin:26px 0 30px;
    font-family:var(--mono);font-size:12px}
  .stage{flex:1;min-width:0;background:linear-gradient(180deg,var(--panel),var(--panel-2));
    border:1px solid var(--line);border-radius:12px;padding:12px 14px}
  .stage .t{color:var(--dim);letter-spacing:.14em;text-transform:uppercase;font-size:10px}
  .stage .m{margin-top:5px;color:var(--text);font-size:13px}
  .stage.web .m{color:var(--amber)}
  .stage.db  .m{color:var(--emerald)}
  .arrow{flex:0 0 40px;display:grid;place-items:center;color:var(--dim);position:relative}
  .arrow span{position:relative}
  .arrow small{position:absolute;top:-15px;left:50%;transform:translateX(-50%);
    font-size:9px;letter-spacing:.12em;color:var(--dim);white-space:nowrap}

  .card{background:linear-gradient(180deg,var(--panel),var(--panel-2));
    border:1px solid var(--line);border-radius:16px;padding:22px 22px 24px;
    box-shadow:0 24px 60px -30px rgba(0,0,0,.8)}
  .card.hero{border-color:rgba(246,177,60,.35);
    box-shadow:0 0 0 1px rgba(246,177,60,.15),0 24px 60px -28px rgba(246,177,60,.35)}
  label{display:block;font-family:var(--mono);font-size:11px;letter-spacing:.14em;
    text-transform:uppercase;color:var(--dim);margin:0 0 6px}
  input,textarea{width:100%;background:#0a1124;border:1px solid var(--line);
    color:var(--text);border-radius:10px;padding:11px 13px;font:inherit;font-size:15px}
  input:focus,textarea:focus{outline:none;border-color:var(--amber);
    box-shadow:0 0 0 3px rgba(246,177,60,.16)}
  textarea{resize:vertical;min-height:84px}
  .field+.field{margin-top:14px}
  .btn{margin-top:18px;width:100%;border:none;cursor:pointer;font:inherit;
    font-weight:600;font-size:15px;color:#1a1204;border-radius:11px;padding:13px 16px;
    background:linear-gradient(180deg,var(--amber-soft),var(--amber));
    box-shadow:0 10px 24px -10px rgba(246,177,60,.7);transition:transform .08s ease}
  .btn:hover{transform:translateY(-1px)}
  .btn:active{transform:translateY(0)}

  .ledger{margin-top:30px}
  .ledger h2{font-family:var(--mono);font-size:13px;letter-spacing:.16em;
    text-transform:uppercase;color:var(--dim);margin:0 0 12px;
    display:flex;align-items:center;gap:10px}
  .badge{font-family:var(--mono);font-size:11px;color:var(--emerald);
    border:1px solid rgba(74,222,128,.4);border-radius:999px;padding:2px 9px}
  table{width:100%;border-collapse:collapse;font-size:14px}
  th,td{text-align:left;padding:10px 12px;border-bottom:1px solid var(--line);vertical-align:top}
  th{font-family:var(--mono);font-size:10.5px;letter-spacing:.12em;text-transform:uppercase;
    color:var(--dim);font-weight:600}
  td.id{font-family:var(--mono);color:var(--amber);width:44px}
  td.who{font-weight:600}
  td.msg{color:var(--text)}
  td.meta{font-family:var(--mono);font-size:11px;color:var(--dim);white-space:nowrap}
  .empty{padding:26px 12px;color:var(--dim);font-size:14px;text-align:center;
    border:1px dashed var(--line);border-radius:12px}
  footer{margin-top:26px;font-family:var(--mono);font-size:11px;color:var(--dim);
    display:flex;justify-content:space-between;gap:12px;flex-wrap:wrap}
  code{background:#0a1124;border:1px solid var(--line);border-radius:6px;
    padding:1px 6px;color:var(--amber-soft)}
  @media(max-width:560px){.pipe{flex-direction:column}.arrow{flex-basis:26px;transform:rotate(90deg)}}
</style>
</head>
<body>
<div class="wrap">
  <div class="eyebrow">OVERLAY LEDGER · <b>app-net</b> · swarm two-tier</div>
  <h1>Write once. Land on the worker.</h1>
  <p class="lede">This page runs in the <strong>web</strong> service on the
    <strong>manager</strong> node. Every entry you submit is written across the overlay
    network into Postgres running in the <strong>db</strong> service on the
    <strong>worker</strong> node — then read straight back.</p>

  <div class="pipe">
    <div class="stage"><div class="t">client</div><div class="m">your browser</div></div>
    <div class="arrow"><span><small>HTTP :8080</small>→</span></div>
    <div class="stage web"><div class="t">web · manager</div><div class="m">%%WEBHOST%%</div></div>
    <div class="arrow"><span><small>overlay</small>→</span></div>
    <div class="stage db"><div class="t">db · worker</div><div class="m">postgres</div></div>
  </div>

  <form class="card hero" method="POST" action="/add">
    <div class="field">
      <label for="name">Name</label>
      <input id="name" name="name" placeholder="e.g. ada" required maxlength="120">
    </div>
    <div class="field">
      <label for="message">Message</label>
      <textarea id="message" name="message" placeholder="Something to persist on the worker…" required maxlength="500"></textarea>
    </div>
    <button class="btn" type="submit">Commit to worker database →</button>
  </form>

  <section class="ledger">
    <h2>Stored rows <span class="badge">live from db@worker</span></h2>
    %%ROWS%%
  </section>

  <footer>
    <span>🐳 swarm · web served by <code>%%WEBHOST%%</code></span>
    <span>verify on worker: <code>psql -U appuser -d appdb -c "SELECT * FROM messages;"</code></span>
  </footer>
</div>
</body>
</html>"""


def render_rows(rows):
    if not rows:
        return ('<div class="empty">No rows yet. Submit the form above — '
                'then check the db container on the worker.</div>')
    body = [
        "<table><thead><tr><th>#</th><th>Name</th><th>Message</th>"
        "<th>Web host</th><th>Stored at (UTC)</th></tr></thead><tbody>"
    ]
    for rid, name, msg, whost, created in rows:
        ts = created.strftime("%Y-%m-%d %H:%M:%S") if created else ""
        body.append(
            f"<tr><td class='id'>{rid}</td>"
            f"<td class='who'>{html.escape(name)}</td>"
            f"<td class='msg'>{html.escape(msg)}</td>"
            f"<td class='meta'>{html.escape(whost or '')}</td>"
            f"<td class='meta'>{ts}</td></tr>"
        )
    body.append("</tbody></table>")
    return "".join(body)


class Handler(BaseHTTPRequestHandler):
    server_version = "twotier/1.0"

    def _send(self, code, body, ctype="text/html; charset=utf-8"):
        data = body.encode() if isinstance(body, str) else body
        self.send_response(code)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(data)))
        self.send_header("X-Web-Host", WEB_HOST)
        self.end_headers()
        self.wfile.write(data)

    def do_GET(self):
        if self.path.startswith("/api/messages"):
            try:
                rows = fetch_rows()
                payload = [
                    {"id": r[0], "name": r[1], "message": r[2],
                     "web_host": r[3],
                     "created_at": r[4].isoformat() if r[4] else None}
                    for r in rows
                ]
                self._send(200, json.dumps({"web_host": WEB_HOST, "rows": payload},
                                           indent=2), "application/json")
            except Exception as e:  # noqa: BLE001
                self._send(500, json.dumps({"error": str(e)}), "application/json")
            return
        if self.path in ("/", "/index.html"):
            try:
                rows = fetch_rows()
                page = (PAGE.replace("%%ROWS%%", render_rows(rows))
                            .replace("%%WEBHOST%%", html.escape(WEB_HOST)))
                self._send(200, page)
            except Exception as e:  # noqa: BLE001
                self._send(503, f"<h1>DB not reachable yet</h1><pre>{html.escape(str(e))}</pre>")
            return
        self._send(404, "not found", "text/plain")

    def do_POST(self):
        if self.path != "/add":
            self._send(404, "not found", "text/plain")
            return
        length = int(self.headers.get("Content-Length", 0))
        form = parse_qs(self.rfile.read(length).decode("utf-8"))
        name = (form.get("name", [""])[0] or "").strip()
        message = (form.get("message", [""])[0] or "").strip()
        if name and message:
            try:
                insert_row(name, message)
            except Exception as e:  # noqa: BLE001
                self._send(500, f"<h1>Insert failed</h1><pre>{html.escape(str(e))}</pre>")
                return
        # Post/Redirect/Get so refresh doesn't re-submit
        self.send_response(303)
        self.send_header("Location", "/")
        self.end_headers()

    def log_message(self, fmt, *args):
        print(f"[web] {self.address_string()} {fmt % args}", flush=True)


if __name__ == "__main__":
    print(f"[web] starting on :{LISTEN_PORT}; db target = {DB['host']}", flush=True)
    init_db()
    ThreadingHTTPServer(("0.0.0.0", LISTEN_PORT), Handler).serve_forever()

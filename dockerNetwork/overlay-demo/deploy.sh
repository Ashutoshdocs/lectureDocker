#!/usr/bin/env bash
# =============================================================================
#  Docker Swarm overlay demo  ·  svc1 (manager) + svc2 (worker)
#  Serves a styled HTML page to browsers and an ANSI terminal page to curl/wget.
#  Run this ON A MANAGER NODE of an initialised swarm:   bash deploy.sh
# =============================================================================
set -euo pipefail

NET=my-overlay-net
SUBNET=20.0.0.0/24
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

echo ">> writing assets to $WORK"

# ---------------------------------------------------------------- index1.html
cat > "$WORK/index1.html" <<'HTML1'
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Container 1 · svc1</title>
<style>
  :root{
    --ink:#070b16; --panel:#0d1424; --panel-2:#111b31;
    --line:#1e2d4a; --cyan:#22d3ee; --blue:#3b82f6; --mint:#5eead4;
    --text:#dce6f5; --dim:#7d8db0; --ok:#34d399;
    --glow:0 0 0 1px rgba(34,211,238,.25), 0 24px 60px -20px rgba(34,211,238,.35);
    --mono:ui-monospace,"SF Mono","JetBrains Mono","Cascadia Code",Menlo,Consolas,monospace;
    --sans:system-ui,-apple-system,"Segoe UI",Roboto,sans-serif;
  }
  *{box-sizing:border-box}
  html,body{height:100%}
  body{
    margin:0; color:var(--text); font-family:var(--sans);
    background:
      radial-gradient(900px 500px at 15% -10%,rgba(34,211,238,.12),transparent 60%),
      radial-gradient(700px 500px at 110% 120%,rgba(59,130,246,.14),transparent 55%),
      linear-gradient(180deg,#060912,#0a1020);
    display:grid; place-items:center; padding:28px;
    background-attachment:fixed;
  }
  body::before{
    content:""; position:fixed; inset:0; pointer-events:none; opacity:.5;
    background-image:
      linear-gradient(rgba(34,211,238,.045) 1px,transparent 1px),
      linear-gradient(90deg,rgba(34,211,238,.045) 1px,transparent 1px);
    background-size:44px 44px;
    -webkit-mask:radial-gradient(circle at 50% 40%,#000,transparent 78%);
            mask:radial-gradient(circle at 50% 40%,#000,transparent 78%);
  }
  .card{
    position:relative; width:min(560px,100%);
    background:linear-gradient(180deg,var(--panel),var(--panel-2));
    border:1px solid var(--line); border-radius:20px; padding:34px 34px 26px;
    box-shadow:var(--glow); overflow:hidden;
  }
  .card::after{ /* top signal bar */
    content:""; position:absolute; inset:0 0 auto 0; height:3px;
    background:linear-gradient(90deg,transparent,var(--cyan),var(--blue),transparent);
    background-size:200% 100%; animation:sweep 3.2s linear infinite;
  }
  .eyebrow{
    font-family:var(--mono); font-size:12px; letter-spacing:.22em; text-transform:uppercase;
    color:var(--dim); display:flex; align-items:center; gap:10px;
  }
  .eyebrow b{color:var(--cyan); font-weight:600; letter-spacing:.16em}
  .status{
    display:inline-flex; align-items:center; gap:9px; margin:22px 0 6px;
    font-family:var(--mono); font-size:13px; letter-spacing:.14em; color:var(--ok);
  }
  .dot{width:9px;height:9px;border-radius:50%;background:var(--ok);
    box-shadow:0 0 0 0 rgba(52,211,153,.6); animation:pulse 1.8s ease-out infinite}
  h1{
    margin:.1em 0 .05em; font-family:var(--mono); font-weight:700;
    font-size:clamp(38px,9vw,58px); line-height:1; letter-spacing:-.02em;
    background:linear-gradient(120deg,#eaf6ff,var(--cyan) 55%,var(--blue));
    -webkit-background-clip:text; background-clip:text; color:transparent;
  }
  .sub{color:var(--dim); font-family:var(--mono); font-size:14px; letter-spacing:.04em}
  .sub em{color:var(--mint); font-style:normal}

  /* topology signature */
  .topo{margin:26px 0 22px; padding:18px 16px; border:1px dashed var(--line);
    border-radius:14px; background:rgba(8,14,28,.5)}
  .wire{display:flex; align-items:center; gap:0; font-family:var(--mono); font-size:12px}
  .node{flex:0 0 auto; text-align:center; padding:10px 12px; border-radius:10px;
    border:1px solid var(--line); background:#0a1122; color:var(--dim); min-width:96px}
  .node .n{display:block; font-size:11px; letter-spacing:.12em; margin-top:4px}
  .node.you{border-color:var(--cyan); color:var(--text);
    box-shadow:0 0 0 1px rgba(34,211,238,.3),0 8px 30px -12px rgba(34,211,238,.7)}
  .node.you .n{color:var(--cyan)}
  .link{flex:1 1 auto; height:2px; position:relative; margin:0 6px;
    background:repeating-linear-gradient(90deg,var(--line) 0 6px,transparent 6px 12px)}
  .pkt{position:absolute; top:50%; left:0; width:8px; height:8px; margin-top:-4px;
    border-radius:50%; background:var(--cyan);
    box-shadow:0 0 10px 2px var(--cyan); animation:travel 2.4s ease-in-out infinite}
  .link .lbl{position:absolute; top:-20px; left:50%; transform:translateX(-50%);
    color:var(--dim); font-size:10px; letter-spacing:.18em; white-space:nowrap}

  .grid{display:grid; grid-template-columns:1fr 1fr; gap:1px;
    background:var(--line); border:1px solid var(--line); border-radius:12px; overflow:hidden}
  .cell{background:var(--panel-2); padding:12px 14px}
  .cell .k{font-family:var(--mono); font-size:10.5px; letter-spacing:.16em;
    text-transform:uppercase; color:var(--dim)}
  .cell .v{font-family:var(--mono); font-size:15px; margin-top:3px; color:var(--text)}
  .cell .v.hi{color:var(--cyan)}
  footer{margin-top:18px; display:flex; justify-content:space-between; align-items:center;
    font-family:var(--mono); font-size:11px; color:var(--dim); letter-spacing:.08em}
  .whale{font-size:15px}

  @keyframes pulse{0%{box-shadow:0 0 0 0 rgba(52,211,153,.55)}
    100%{box-shadow:0 0 0 12px rgba(52,211,153,0)}}
  @keyframes sweep{0%{background-position:200% 0}100%{background-position:-200% 0}}
  @keyframes travel{0%{left:2%}45%{left:96%}55%{left:96%}100%{left:2%}}
  @media (max-width:420px){.grid{grid-template-columns:1fr}}
  @media (prefers-reduced-motion:reduce){
    .card::after,.dot,.pkt{animation:none}
  }
</style>
</head>
<body>
  <main class="card">
    <div class="eyebrow">OVERLAY&nbsp;NET · <b>my-overlay-net</b> · 20.0.0.0/24</div>

    <div class="status"><span class="dot"></span>CONNECTION ESTABLISHED</div>
    <h1>Container&nbsp;1</h1>
    <p class="sub">service <em>svc1</em> · pinned to the <em>manager</em> node</p>

    <section class="topo" aria-label="overlay topology">
      <div class="wire">
        <div class="node you">◉<span class="n">svc1 · YOU</span></div>
        <div class="link"><span class="lbl">OVERLAY TUNNEL</span><span class="pkt"></span></div>
        <div class="node">○<span class="n">svc2</span></div>
      </div>
    </section>

    <div class="grid">
      <div class="cell"><div class="k">Service</div><div class="v hi">svc1</div></div>
      <div class="cell"><div class="k">Node role</div><div class="v">manager</div></div>
      <div class="cell"><div class="k">Network</div><div class="v">my-overlay-net</div></div>
      <div class="cell"><div class="k">Driver</div><div class="v">overlay</div></div>
      <div class="cell"><div class="k">Published port</div><div class="v hi">8081 → 80</div></div>
      <div class="cell"><div class="k">Container host</div>
        <div class="v"><!--#echo var="ct_host" default="—" --></div></div>
    </div>

    <footer>
      <span class="whale">🐳 docker swarm</span>
      <span>nginx:alpine · reached via curl or browser</span>
    </footer>
  </main>
</body>
</html>
HTML1

# ---------------------------------------------------------------- index2.html
cat > "$WORK/index2.html" <<'HTML2'
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Container 2 · svc2</title>
<style>
  :root{
    --ink:#0d0716; --panel:#160c24; --panel-2:#1c1030;
    --line:#3a2352; --magenta:#e879f9; --violet:#8b5cf6; --amber:#fbbf24;
    --text:#f1e6ff; --dim:#a690c4; --ok:#34d399;
    --glow:0 0 0 1px rgba(232,121,249,.25), 0 24px 60px -20px rgba(232,121,249,.35);
    --mono:ui-monospace,"SF Mono","JetBrains Mono","Cascadia Code",Menlo,Consolas,monospace;
    --sans:system-ui,-apple-system,"Segoe UI",Roboto,sans-serif;
  }
  *{box-sizing:border-box}
  html,body{height:100%}
  body{
    margin:0; color:var(--text); font-family:var(--sans);
    background:
      radial-gradient(900px 500px at 12% -10%,rgba(232,121,249,.13),transparent 60%),
      radial-gradient(700px 500px at 112% 120%,rgba(139,92,246,.16),transparent 55%),
      linear-gradient(180deg,#0a0512,#140a20);
    display:grid; place-items:center; padding:28px; background-attachment:fixed;
  }
  body::before{
    content:""; position:fixed; inset:0; pointer-events:none; opacity:.5;
    background-image:
      linear-gradient(rgba(232,121,249,.05) 1px,transparent 1px),
      linear-gradient(90deg,rgba(232,121,249,.05) 1px,transparent 1px);
    background-size:44px 44px;
    -webkit-mask:radial-gradient(circle at 50% 40%,#000,transparent 78%);
            mask:radial-gradient(circle at 50% 40%,#000,transparent 78%);
  }
  .card{
    position:relative; width:min(560px,100%);
    background:linear-gradient(180deg,var(--panel),var(--panel-2));
    border:1px solid var(--line); border-radius:20px; padding:34px 34px 26px;
    box-shadow:var(--glow); overflow:hidden;
  }
  .card::after{
    content:""; position:absolute; inset:0 0 auto 0; height:3px;
    background:linear-gradient(90deg,transparent,var(--magenta),var(--amber),transparent);
    background-size:200% 100%; animation:sweep 3.2s linear infinite;
  }
  .eyebrow{
    font-family:var(--mono); font-size:12px; letter-spacing:.22em; text-transform:uppercase;
    color:var(--dim); display:flex; align-items:center; gap:10px;
  }
  .eyebrow b{color:var(--magenta); font-weight:600; letter-spacing:.16em}
  .status{
    display:inline-flex; align-items:center; gap:9px; margin:22px 0 6px;
    font-family:var(--mono); font-size:13px; letter-spacing:.14em; color:var(--ok);
  }
  .dot{width:9px;height:9px;border-radius:50%;background:var(--ok);
    box-shadow:0 0 0 0 rgba(52,211,153,.6); animation:pulse 1.8s ease-out infinite}
  h1{
    margin:.1em 0 .05em; font-family:var(--mono); font-weight:700;
    font-size:clamp(38px,9vw,58px); line-height:1; letter-spacing:-.02em;
    background:linear-gradient(120deg,#fdeaff,var(--magenta) 52%,var(--amber));
    -webkit-background-clip:text; background-clip:text; color:transparent;
  }
  .sub{color:var(--dim); font-family:var(--mono); font-size:14px; letter-spacing:.04em}
  .sub em{color:var(--amber); font-style:normal}

  .topo{margin:26px 0 22px; padding:18px 16px; border:1px dashed var(--line);
    border-radius:14px; background:rgba(14,7,22,.5)}
  .wire{display:flex; align-items:center; gap:0; font-family:var(--mono); font-size:12px}
  .node{flex:0 0 auto; text-align:center; padding:10px 12px; border-radius:10px;
    border:1px solid var(--line); background:#150a24; color:var(--dim); min-width:96px}
  .node .n{display:block; font-size:11px; letter-spacing:.12em; margin-top:4px}
  .node.you{border-color:var(--magenta); color:var(--text);
    box-shadow:0 0 0 1px rgba(232,121,249,.3),0 8px 30px -12px rgba(232,121,249,.7)}
  .node.you .n{color:var(--magenta)}
  .link{flex:1 1 auto; height:2px; position:relative; margin:0 6px;
    background:repeating-linear-gradient(90deg,var(--line) 0 6px,transparent 6px 12px)}
  .pkt{position:absolute; top:50%; left:0; width:8px; height:8px; margin-top:-4px;
    border-radius:50%; background:var(--magenta);
    box-shadow:0 0 10px 2px var(--magenta); animation:travel 2.4s ease-in-out infinite}
  .link .lbl{position:absolute; top:-20px; left:50%; transform:translateX(-50%);
    color:var(--dim); font-size:10px; letter-spacing:.18em; white-space:nowrap}

  .grid{display:grid; grid-template-columns:1fr 1fr; gap:1px;
    background:var(--line); border:1px solid var(--line); border-radius:12px; overflow:hidden}
  .cell{background:var(--panel-2); padding:12px 14px}
  .cell .k{font-family:var(--mono); font-size:10.5px; letter-spacing:.16em;
    text-transform:uppercase; color:var(--dim)}
  .cell .v{font-family:var(--mono); font-size:15px; margin-top:3px; color:var(--text)}
  .cell .v.hi{color:var(--magenta)}
  footer{margin-top:18px; display:flex; justify-content:space-between; align-items:center;
    font-family:var(--mono); font-size:11px; color:var(--dim); letter-spacing:.08em}
  .whale{font-size:15px}

  @keyframes pulse{0%{box-shadow:0 0 0 0 rgba(52,211,153,.55)}
    100%{box-shadow:0 0 0 12px rgba(52,211,153,0)}}
  @keyframes sweep{0%{background-position:200% 0}100%{background-position:-200% 0}}
  @keyframes travel{0%{left:96%}45%{left:2%}55%{left:2%}100%{left:96%}}
  @media (max-width:420px){.grid{grid-template-columns:1fr}}
  @media (prefers-reduced-motion:reduce){
    .card::after,.dot,.pkt{animation:none}
  }
</style>
</head>
<body>
  <main class="card">
    <div class="eyebrow">OVERLAY&nbsp;NET · <b>my-overlay-net</b> · 20.0.0.0/24</div>

    <div class="status"><span class="dot"></span>CONNECTION ESTABLISHED</div>
    <h1>Container&nbsp;2</h1>
    <p class="sub">service <em>svc2</em> · pinned to the <em>worker</em> node</p>

    <section class="topo" aria-label="overlay topology">
      <div class="wire">
        <div class="node">○<span class="n">svc1</span></div>
        <div class="link"><span class="lbl">OVERLAY TUNNEL</span><span class="pkt"></span></div>
        <div class="node you">◉<span class="n">svc2 · YOU</span></div>
      </div>
    </section>

    <div class="grid">
      <div class="cell"><div class="k">Service</div><div class="v hi">svc2</div></div>
      <div class="cell"><div class="k">Node role</div><div class="v">worker</div></div>
      <div class="cell"><div class="k">Network</div><div class="v">my-overlay-net</div></div>
      <div class="cell"><div class="k">Driver</div><div class="v">overlay</div></div>
      <div class="cell"><div class="k">Published port</div><div class="v hi">8082 → 80</div></div>
      <div class="cell"><div class="k">Container host</div>
        <div class="v"><!--#echo var="ct_host" default="—" --></div></div>
    </div>

    <footer>
      <span class="whale">🐳 docker swarm</span>
      <span>nginx:alpine · reached via curl or browser</span>
    </footer>
  </main>
</body>
</html>
HTML2

# ---------------------------------------------------------------- default.conf
cat > "$WORK/default.conf" <<'CONF'
# Content negotiation by client:
#   browsers            -> index.html  (full styled page)
#   curl / wget / fetch -> cli.txt      (ANSI-coloured terminal page)
map $http_user_agent $root_doc {
    default   /index.html;
    ~*curl    /cli.txt;
    ~*wget    /cli.txt;
    ~*fetch   /cli.txt;
    ~*libwww  /cli.txt;
    ~*httpie  /cli.txt;
}

server {
    listen 80;
    server_name _;
    root  /usr/share/nginx/html;

    charset utf-8;

    # Show which replica/host answered (visible in `curl -I` and browser dev tools)
    add_header X-Served-By  $hostname        always;
    add_header X-Overlay    "my-overlay-net" always;

    # Root path: pick the document based on the client.
    location = / {
        ssi on;                 # lets index.html print the container hostname
        set $ct_host $hostname; # SSI variable used by <!--#echo var="ct_host"-->
        try_files $root_doc =404;
    }

    # Everything else served normally (so /cli.txt, /index.html still work directly).
    location / {
        try_files $uri $uri/ =404;
    }
}
CONF

# --------------------------------------------------- ANSI terminal pages (b64)
echo 'CiAgG1szODs1OzI0NG1vdmVybGF5LW5ldCBkZW1vIMK3IG15LW92ZXJsYXktbmV0IMK3IDIwLjAuMC4wLzI0G1swbQogIBtbMzg7NTszOW3ila3ilIDilIDilIDilIDilIDilIDilIDilIDilIDilIDilIDilIDilIDilIDilIDilIDilIDilIDilIDilIDilIDilIDilIDilIDilIDilIDilIDilIDilIDilIDilIDilIDilIDilIDilIDilIDilIDilIDilIDilIDilIDilIDilIDilIDilIDilIDilIDilIDilIDilIDilIDilIDilIDilIDilIDilIDila4bWzBtCiAgG1szODs1OzM5beKUghtbMG0gG1sxOzM4OzU7NDJt4peJIENPTk5FQ1RJT04gRVNUQUJMSVNIRUQbWzBtICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIBtbMzg7NTszOW3ilIIbWzBtCiAgG1szODs1OzM5beKUghtbMG0gICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIBtbMzg7NTszOW3ilIIbWzBtCiAgG1szODs1OzM5beKUghtbMG0gG1sxOzM4OzU7Mzlt4paI4paIICBDT05UQUlORVIgMRtbMG0gICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgG1szODs1OzM5beKUghtbMG0KICAbWzM4OzU7Mzlt4pSCG1swbSAbWzM4OzU7MjQ0bXNlcnZpY2UgG1swbRtbMTszODs1OzQ4bXN2YzEbWzBtG1szODs1OzI0NG0gwrcgbWFuYWdlciBub2RlG1swbSAgICAgICAgICAgICAgICAgICAgICAgICAgICAbWzM4OzU7Mzlt4pSCG1swbQogIBtbMzg7NTszOW3ilIIbWzBtICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAbWzM4OzU7Mzlt4pSCG1swbQogIBtbMzg7NTszOW3ilIIbWzBtIBtbMTszODs1OzM5bVsgc3ZjMSDil4kgXRtbMG0gG1szODs1OzM5beKVkOKVkBtbMG0gG1szODs1OzI0NG1vdmVybGF5G1swbSAbWzM4OzU7Mzlt4pWQ4pWQG1swbSAbWzM4OzU7MjQ0bVsgc3ZjMiDil4sgXRtbMG0gICAgICAgICAgICAgICAgICAgIBtbMzg7NTszOW3ilIIbWzBtCiAgG1szODs1OzM5beKUghtbMG0gICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIBtbMzg7NTszOW3ilIIbWzBtCiAgG1szODs1OzM5beKUghtbMG0gG1szODs1OzI0NG1zZXJ2aWNlICAgICAgIBtbMG0bWzE7Mzg7NTs0OG1zdmMxG1swbSAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAbWzM4OzU7Mzlt4pSCG1swbQogIBtbMzg7NTszOW3ilIIbWzBtIBtbMzg7NTsyNDRtbm9kZSByb2xlICAgICAbWzBtG1sxOzk3bW1hbmFnZXIbWzBtICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIBtbMzg7NTszOW3ilIIbWzBtCiAgG1szODs1OzM5beKUghtbMG0gG1szODs1OzI0NG1uZXR3b3JrICAgICAgIBtbMG0bWzE7OTdtbXktb3ZlcmxheS1uZXQbWzBtICAgICAgICAgICAgICAgICAgICAgICAgICAgG1szODs1OzM5beKUghtbMG0KICAbWzM4OzU7Mzlt4pSCG1swbSAbWzM4OzU7MjQ0bWRyaXZlciAgICAgICAgG1swbRtbMTs5N21vdmVybGF5G1swbSAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAbWzM4OzU7Mzlt4pSCG1swbQogIBtbMzg7NTszOW3ilIIbWzBtIBtbMzg7NTsyNDRtc3VibmV0ICAgICAgICAbWzBtG1sxOzk3bTIwLjAuMC4wLzI0G1swbSAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIBtbMzg7NTszOW3ilIIbWzBtCiAgG1szODs1OzM5beKUghtbMG0gG1szODs1OzI0NG1wdWJsaXNoZWQgICAgIBtbMG0bWzE7Mzg7NTs0OG04MDgxIC0+IDgwG1swbSAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAbWzM4OzU7Mzlt4pSCG1swbQogIBtbMzg7NTszOW3ilIIbWzBtICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAbWzM4OzU7Mzlt4pSCG1swbQogIBtbMzg7NTszOW3ilIIbWzBtIBtbMzg7NTsyNDRt8J+QsyBkb2NrZXIgc3dhcm0gwrcgbmdpbng6YWxwaW5lIMK3IHZpYSBjdXJsG1swbSAgICAgICAgICAgICAgG1szODs1OzM5beKUghtbMG0KICAbWzM4OzU7Mzlt4pWw4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pWvG1swbQoK' | base64 -d > "$WORK/cli1.txt"
echo 'CiAgG1szODs1OzI0NG1vdmVybGF5LW5ldCBkZW1vIMK3IG15LW92ZXJsYXktbmV0IMK3IDIwLjAuMC4wLzI0G1swbQogIBtbMzg7NTsyMDdt4pWt4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pWuG1swbQogIBtbMzg7NTsyMDdt4pSCG1swbSAbWzE7Mzg7NTs0Mm3il4kgQ09OTkVDVElPTiBFU1RBQkxJU0hFRBtbMG0gICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgG1szODs1OzIwN23ilIIbWzBtCiAgG1szODs1OzIwN23ilIIbWzBtICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAbWzM4OzU7MjA3beKUghtbMG0KICAbWzM4OzU7MjA3beKUghtbMG0gG1sxOzM4OzU7MjA3beKWiOKWiCAgQ09OVEFJTkVSIDIbWzBtICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIBtbMzg7NTsyMDdt4pSCG1swbQogIBtbMzg7NTsyMDdt4pSCG1swbSAbWzM4OzU7MjQ0bXNlcnZpY2UgG1swbRtbMTszODs1OzIxNG1zdmMyG1swbRtbMzg7NTsyNDRtIMK3IHdvcmtlciBub2RlG1swbSAgICAgICAgICAgICAgICAgICAgICAgICAgICAgG1szODs1OzIwN23ilIIbWzBtCiAgG1szODs1OzIwN23ilIIbWzBtICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAbWzM4OzU7MjA3beKUghtbMG0KICAbWzM4OzU7MjA3beKUghtbMG0gG1szODs1OzI0NG1bIHN2YzEg4peLIF0bWzBtIBtbMzg7NTsyMDdt4pWQ4pWQG1swbSAbWzM4OzU7MjQ0bW92ZXJsYXkbWzBtIBtbMzg7NTsyMDdt4pWQ4pWQG1swbSAbWzE7Mzg7NTsyMDdtWyBzdmMyIOKXiSBdG1swbSAgICAgICAgICAgICAgICAgICAgG1szODs1OzIwN23ilIIbWzBtCiAgG1szODs1OzIwN23ilIIbWzBtICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAbWzM4OzU7MjA3beKUghtbMG0KICAbWzM4OzU7MjA3beKUghtbMG0gG1szODs1OzI0NG1zZXJ2aWNlICAgICAgIBtbMG0bWzE7Mzg7NTsyMTRtc3ZjMhtbMG0gICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgG1szODs1OzIwN23ilIIbWzBtCiAgG1szODs1OzIwN23ilIIbWzBtIBtbMzg7NTsyNDRtbm9kZSByb2xlICAgICAbWzBtG1sxOzk3bXdvcmtlchtbMG0gICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIBtbMzg7NTsyMDdt4pSCG1swbQogIBtbMzg7NTsyMDdt4pSCG1swbSAbWzM4OzU7MjQ0bW5ldHdvcmsgICAgICAgG1swbRtbMTs5N21teS1vdmVybGF5LW5ldBtbMG0gICAgICAgICAgICAgICAgICAgICAgICAgICAbWzM4OzU7MjA3beKUghtbMG0KICAbWzM4OzU7MjA3beKUghtbMG0gG1szODs1OzI0NG1kcml2ZXIgICAgICAgIBtbMG0bWzE7OTdtb3ZlcmxheRtbMG0gICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgG1szODs1OzIwN23ilIIbWzBtCiAgG1szODs1OzIwN23ilIIbWzBtIBtbMzg7NTsyNDRtc3VibmV0ICAgICAgICAbWzBtG1sxOzk3bTIwLjAuMC4wLzI0G1swbSAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIBtbMzg7NTsyMDdt4pSCG1swbQogIBtbMzg7NTsyMDdt4pSCG1swbSAbWzM4OzU7MjQ0bXB1Ymxpc2hlZCAgICAgG1swbRtbMTszODs1OzIxNG04MDgyIC0+IDgwG1swbSAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAbWzM4OzU7MjA3beKUghtbMG0KICAbWzM4OzU7MjA3beKUghtbMG0gICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIBtbMzg7NTsyMDdt4pSCG1swbQogIBtbMzg7NTsyMDdt4pSCG1swbSAbWzM4OzU7MjQ0bfCfkLMgZG9ja2VyIHN3YXJtIMK3IG5naW54OmFscGluZSDCtyB2aWEgY3VybBtbMG0gICAgICAgICAgICAgIBtbMzg7NTsyMDdt4pSCG1swbQogIBtbMzg7NTsyMDdt4pWw4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pWvG1swbQoK' | base64 -d > "$WORK/cli2.txt"

# --------------------------------------------------------------- overlay net
if docker network inspect "$NET" >/dev/null 2>&1; then
  echo ">> network $NET already exists"
else
  echo ">> creating overlay network $NET ($SUBNET)"
  docker network create --driver overlay --subnet "$SUBNET" "$NET"
fi

# ------------------------------------------------------------- node labels
MANAGER_ID="$(docker info -f '{{.Swarm.NodeID}}')"
WORKER_ID="$(docker node ls --filter role=worker -q | head -n1 || true)"

echo ">> labelling manager node $MANAGER_ID  role=manager"
docker node update --label-add role=manager "$MANAGER_ID" >/dev/null

if [ -n "$WORKER_ID" ]; then
  echo ">> labelling worker node  $WORKER_ID  role=worker"
  docker node update --label-add role=worker "$WORKER_ID" >/dev/null
  SVC2_CONSTRAINT='node.labels.role==worker'
else
  echo "!! no worker node in this swarm — pinning svc2 to the manager as well"
  SVC2_CONSTRAINT='node.labels.role==manager'
fi

# ------------------------------------------- remove old services + configs
echo ">> clearing any previous svc1/svc2 + configs"
docker service rm svc1 svc2 >/dev/null 2>&1 || true
# wait for the tasks (and their config references) to drain
for _ in $(seq 1 15); do
  docker service ls --format '{{.Name}}' | grep -qE '^svc[12]$' || break
  sleep 1
done
sleep 2

recreate_config() {  # name  file
  docker config rm "$1" >/dev/null 2>&1 || true
  docker config create "$1" "$2" >/dev/null
}
recreate_config ovl-nginx-conf "$WORK/default.conf"
recreate_config svc1-index     "$WORK/index1.html"
recreate_config svc1-cli       "$WORK/cli1.txt"
recreate_config svc2-index     "$WORK/index2.html"
recreate_config svc2-cli       "$WORK/cli2.txt"

# --------------------------------------------------------------- services
echo ">> creating svc1 (manager, :8081)"
docker service create --name svc1 \
  --constraint 'node.labels.role==manager' \
  --network "$NET" \
  --publish published=8081,target=80 \
  --config source=ovl-nginx-conf,target=/etc/nginx/conf.d/default.conf \
  --config source=svc1-index,target=/usr/share/nginx/html/index.html \
  --config source=svc1-cli,target=/usr/share/nginx/html/cli.txt \
  nginx:alpine >/dev/null

echo ">> creating svc2 ($SVC2_CONSTRAINT, :8082)"
docker service create --name svc2 \
  --constraint "$SVC2_CONSTRAINT" \
  --network "$NET" \
  --publish published=8082,target=80 \
  --config source=ovl-nginx-conf,target=/etc/nginx/conf.d/default.conf \
  --config source=svc2-index,target=/usr/share/nginx/html/index.html \
  --config source=svc2-cli,target=/usr/share/nginx/html/cli.txt \
  nginx:alpine >/dev/null

# ---------------------------------------------------------------- summary
IP="$(hostname -I 2>/dev/null | awk '{print $1}')"
echo
echo "=============================================================="
echo " Deployed.  svc1 -> :8081   svc2 -> :8082"
echo "--------------------------------------------------------------"
echo " Terminal (ANSI page):"
echo "   curl http://${IP:-<vm-ip>}:8081"
echo "   curl http://${IP:-<vm-ip>}:8082"
echo " Browser (styled HTML):"
echo "   http://${IP:-<vm-ip>}:8081"
echo "   http://${IP:-<vm-ip>}:8082"
echo "--------------------------------------------------------------"
echo " Watch rollout:  docker service ls ; docker service ps svc1 svc2"
echo "=============================================================="

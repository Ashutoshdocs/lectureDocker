#!/usr/bin/env python3
# Generates cli1.txt and cli2.txt : ANSI-coloured pages shown to curl/wget.
import re, os

R   = "\033[0m"
B   = "\033[1m"
DIM = "\033[38;5;244m"
GRN = "\033[1;38;5;42m"
WHT = "\033[1;97m"

WIDE = set("🐳")           # chars that occupy 2 terminal cells
ANSI = re.compile(r"\033\[[0-9;]*m")

def vlen(s):
    s = ANSI.sub("", s)
    return sum(2 if c in WIDE else 1 for c in s)

INNER = 54

def theme(primary, accent):
    P  = f"\033[1;38;5;{primary}m"   # bold primary
    p  = f"\033[38;5;{primary}m"     # primary
    A  = f"\033[1;38;5;{accent}m"    # bold accent
    return P, p, A

def build(num, svc, role, port, you_left, primary, accent):
    P, p, A = theme(primary, accent)
    TL,TR,BL,BR,H,V = "╭","╮","╰","╯","─","│"

    def row(inner=""):
        pad = INNER - vlen(inner)
        return f"  {p}{V}{R} {inner}{' '*max(pad,0)} {p}{V}{R}"

    # topology line
    left  = f"{P}[ svc1 ◉ ]{R}" if you_left else f"{DIM}[ svc1 ○ ]{R}"
    right = f"{DIM}[ svc2 ○ ]{R}" if you_left else f"{P}[ svc2 ◉ ]{R}"
    tunnel = f"{p}══{R} {DIM}overlay{R} {p}══{R}"
    topo = f"{left} {tunnel} {right}"

    def kv(k, v, hi=False):
        vc = A if hi else WHT
        return f"{DIM}{k.ljust(14)}{R}{vc}{v}{R}"

    out = []
    out.append("")
    out.append(f"  {DIM}overlay-net demo · my-overlay-net · 20.0.0.0/24{R}")
    out.append(f"  {p}{TL}{H*(INNER+2)}{TR}{R}")
    out.append(row(f"{GRN}◉ CONNECTION ESTABLISHED{R}"))
    out.append(row())
    out.append(row(f"{P}██  CONTAINER {num}{R}"))
    out.append(row(f"{DIM}service {R}{A}{svc}{R}{DIM} · {role} node{R}"))
    out.append(row())
    out.append(row(topo))
    out.append(row())
    out.append(row(kv("service", svc, hi=True)))
    out.append(row(kv("node role", role)))
    out.append(row(kv("network", "my-overlay-net")))
    out.append(row(kv("driver", "overlay")))
    out.append(row(kv("subnet", "20.0.0.0/24")))
    out.append(row(kv("published", f"{port} -> 80", hi=True)))
    out.append(row())
    out.append(row(f"{DIM}🐳 docker swarm · nginx:alpine · via curl{R}"))
    out.append(f"  {p}{BL}{H*(INNER+2)}{BR}{R}")
    out.append("")
    return "\n".join(out) + "\n"

here = os.path.join(os.path.dirname(__file__), "assets")
os.makedirs(here, exist_ok=True)

# Container 1 : cyan (39), mint accent (48). Manager, port 8081, "you" on left.
with open(os.path.join(here, "cli1.txt"), "w") as f:
    f.write(build("1", "svc1", "manager", "8081", True, 39, 48))

# Container 2 : magenta (207), amber accent (214). Worker, port 8082, "you" on right.
with open(os.path.join(here, "cli2.txt"), "w") as f:
    f.write(build("2", "svc2", "worker", "8082", False, 207, 214))

print("wrote assets/cli1.txt and assets/cli2.txt")

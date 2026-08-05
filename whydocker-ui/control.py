#!/usr/bin/env python3
"""
control.py  --  Backend for the "Why Docker" UI practical.

Serves a dashboard at http://<vm-ip>:9000 and wires its buttons to real commands.

  VM zone      one shared runtime slot on port 8080.
               Starting Java 8 stops Java 17 and vice-versa -> only ONE page.

  Docker zone  builds two images and runs two containers on 8081 / 8082.
               Both pages stay up at the SAME time.

Standard library only. No pip installs. Run it with:  python3 control.py
"""

import glob
import json
import os
import subprocess
import sys
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import urlparse, parse_qs

# ---------------------------------------------------------------- config
APP_DIR   = os.path.dirname(os.path.abspath(__file__))
DASH_PORT = 9000     # dashboard
VM_PORT   = 8080     # the single VM app page
D8_PORT   = 8081     # docker java8 container -> host
D17_PORT  = 8082     # docker java17 container -> host

def find_jdk(patterns):
    for p in patterns:
        for d in sorted(glob.glob(p)):
            if os.path.exists(os.path.join(d, "bin", "java")):
                return d
    return None

# override with JAVA8_HOME / JAVA17_HOME if auto-detect misses on your VM
JDK8  = os.environ.get("JAVA8_HOME")  or find_jdk(["/usr/lib/jvm/java-8-openjdk*",  "/usr/lib/jvm/*1.8*"])
JDK17 = os.environ.get("JAVA17_HOME") or find_jdk(["/usr/lib/jvm/java-17-openjdk*", "/usr/lib/jvm/*-17-*"])

# ---------------------------------------------------------------- state
vm_proc = None       # subprocess.Popen for the single VM app
vm_version = None    # "8" or "17"

def sh(cmd, timeout=180):
    """Run a shell command, return (rc, combined_output)."""
    try:
        r = subprocess.run(cmd, cwd=APP_DIR, shell=True, capture_output=True,
                           text=True, timeout=timeout)
        return r.returncode, (r.stdout + r.stderr).strip()
    except subprocess.TimeoutExpired:
        return 124, "timed out"
    except Exception as e:
        return 1, str(e)

def have_docker():
    return sh("docker --version")[0] == 0

def javac_for_compile():
    """Prefer JDK8 javac so the class runs on BOTH 8 and 17."""
    if JDK8:  return os.path.join(JDK8,  "bin", "javac")
    if JDK17: return os.path.join(JDK17, "bin", "javac")
    return None

def compile_app():
    jc = javac_for_compile()
    if not jc:
        return "No JDK found. Set JAVA8_HOME / JAVA17_HOME or install openjdk-8-jdk."
    rc, out = sh('"%s" -encoding UTF-8 Server.java' % jc)
    return None if rc == 0 else ("compile failed: " + out)

# ---------------------------------------------------------------- VM actions
def vm_start(v):
    global vm_proc, vm_version
    jdk = JDK8 if v == "8" else JDK17
    if not jdk:
        return False, "Java %s not found on this VM." % v
    vm_stop()  # single slot: whatever ran before is torn down first
    java = os.path.join(jdk, "bin", "java")
    env = dict(os.environ, PORT=str(VM_PORT))
    log = open(os.path.join(APP_DIR, "vm.log"), "w")
    vm_proc = subprocess.Popen([java, "Server"], cwd=APP_DIR,
                               env=env, stdout=log, stderr=log)
    vm_version = v
    return True, "Java %s app started on port %d (single runtime slot)." % (v, VM_PORT)

def vm_stop():
    global vm_proc, vm_version
    if vm_proc and vm_proc.poll() is None:
        vm_proc.terminate()
        try: vm_proc.wait(timeout=5)
        except Exception: vm_proc.kill()
    vm_proc = None
    vm_version = None
    return True, "VM app stopped."

def vm_running():
    return vm_proc is not None and vm_proc.poll() is None

# ---------------------------------------------------------------- Docker actions
def docker_build():
    if not have_docker():
        return False, "Docker is not installed / not on PATH."
    rc1, o1 = sh("docker build -t app-java8  -f Dockerfile.java8  .")
    if rc1 != 0: return False, "java8 image build failed:\n" + o1
    rc2, o2 = sh("docker build -t app-java17 -f Dockerfile.java17 .")
    if rc2 != 0: return False, "java17 image build failed:\n" + o2
    return True, "Both images built: app-java8, app-java17."

def docker_run():
    if not have_docker():
        return False, "Docker is not installed / not on PATH."
    sh("docker rm -f java8-container java17-container")  # clean slate
    rc1, o1 = sh("docker run -d --name java8-container  -p %d:8080 -e PORT=8080 app-java8"  % D8_PORT)
    rc2, o2 = sh("docker run -d --name java17-container -p %d:8080 -e PORT=8080 app-java17" % D17_PORT)
    if rc1 != 0 or rc2 != 0:
        return False, "run failed:\n" + o1 + "\n" + o2 + "\n(did you build the images first?)"
    return True, "Both containers running: :%d (Java 8) and :%d (Java 17)." % (D8_PORT, D17_PORT)

def docker_stop():
    sh("docker rm -f java8-container java17-container")
    return True, "Both containers removed."

def container_status(name):
    rc, out = sh('docker ps --filter "name=%s" --format "{{.Status}}"' % name)
    return out if (rc == 0 and out) else ""

# ---------------------------------------------------------------- status
def status():
    docker = have_docker()
    return {
        "env": {
            "jdk8":   bool(JDK8),
            "jdk17":  bool(JDK17),
            "docker": docker,
            "jdk8_path":  JDK8  or "",
            "jdk17_path": JDK17 or "",
        },
        "ports": {"vm": VM_PORT, "d8": D8_PORT, "d17": D17_PORT},
        "vm": {"running": vm_running(), "version": vm_version},
        "docker": {
            "java8":  container_status("java8-container")  if docker else "",
            "java17": container_status("java17-container") if docker else "",
        },
    }

# ---------------------------------------------------------------- HTTP
class Handler(BaseHTTPRequestHandler):
    def log_message(self, *a):  # quiet
        pass

    def _json(self, obj, code=200):
        b = json.dumps(obj).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(b)))
        self.end_headers()
        self.wfile.write(b)

    def _file(self, name, ctype):
        path = os.path.join(APP_DIR, name)
        if not os.path.exists(path):
            self.send_error(404, "%s not found" % name); return
        with open(path, "rb") as f:
            b = f.read()
        self.send_response(200)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(b)))
        self.end_headers()
        self.wfile.write(b)

    def route(self):
        u = urlparse(self.path)
        q = parse_qs(u.query)
        path = u.path

        if path in ("/", "/index.html"):
            return self._file("dashboard.html", "text/html; charset=utf-8")
        if path == "/api/status":
            return self._json(status())
        if path == "/api/vm/start":
            ok, msg = vm_start(q.get("v", ["8"])[0]);      return self._json({"ok": ok, "msg": msg})
        if path == "/api/vm/stop":
            ok, msg = vm_stop();                           return self._json({"ok": ok, "msg": msg})
        if path == "/api/docker/build":
            ok, msg = docker_build();                      return self._json({"ok": ok, "msg": msg})
        if path == "/api/docker/run":
            ok, msg = docker_run();                        return self._json({"ok": ok, "msg": msg})
        if path == "/api/docker/stop":
            ok, msg = docker_stop();                       return self._json({"ok": ok, "msg": msg})
        self.send_error(404, "no route: " + path)

    def do_GET(self):  self.route()
    def do_POST(self): self.route()

def main():
    err = compile_app()
    print("=" * 56)
    print(" Why-Docker UI practical  ::  control server")
    print("=" * 56)
    print(" JDK 8   :", JDK8  or "NOT FOUND")
    print(" JDK 17  :", JDK17 or "NOT FOUND")
    print(" Docker  :", "yes" if have_docker() else "no")
    if err: print(" compile :", err)
    else:   print(" compile : Server.class ready")
    print("-" * 56)
    print(" Open the dashboard:  http://<this-vm-ip>:%d" % DASH_PORT)
    print(" (open ports %d, %d, %d, %d in your firewall / Azure NSG)"
          % (DASH_PORT, VM_PORT, D8_PORT, D17_PORT))
    print("=" * 56)
    try:
        ThreadingHTTPServer(("0.0.0.0", DASH_PORT), Handler).serve_forever()
    except KeyboardInterrupt:
        vm_stop()
        print("\nbye.")

if __name__ == "__main__":
    main()

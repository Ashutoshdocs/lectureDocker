# Why Docker — Java Runtime Control Practical

A hands-on demo that shows the difference between running apps on a **plain VM** and running them in **Docker**.

- **The VM way** — the host has a *single* system Java. Start Java 8 and Java 17 stops; start Java 17 and Java 8 stops. Only **one page** can ever be live, on port `8080`.
- **The Docker way** — each Java version ships in its own container with its own runtime. Build once, run both, and **both pages stay live at the same time**, on ports `8081` and `8082`.

A control dashboard on port `9000` wires real buttons to real commands so you can watch this happen live.

---

## What's in this folder

| File | Purpose |
|------|---------|
| `Server.java` | Tiny web app that prints the **actual Java runtime** executing it. Java 8 source-compatible, so the same file runs on any JVM. |
| `control.py` | Backend control server. Serves the dashboard on `:9000` and runs the VM/Docker commands. Standard library only — no `pip install`. |
| `dashboard.html` | The dashboard UI (served by `control.py`). |
| `Dockerfile.java8` | Builds the Java 8 image (`eclipse-temurin:8-jdk`). |
| `Dockerfile.java17` | Builds the Java 17 image (`eclipse-temurin:17-jdk`). |
| `practicalsetup.sh` | Installs Java 8, Java 17, Docker, and Python on Ubuntu 24.04. |
| `containersetup.sh` | Standalone script to build + run both containers from the command line (optional — the dashboard does this for you). |

---

## Prerequisites

- An **Ubuntu 24.04** VM (or similar).
- `sudo` access.
- These ports open in your firewall / cloud security group (e.g. Azure NSG, AWS Security Group):
  - `9000` — dashboard
  - `8080` — VM app
  - `8081` — Docker Java 8 container
  - `8082` — Docker Java 17 container

---

## Steps to follow

### 1. Copy the files onto the VM

Put all files in a single directory, then `cd` into it:

```bash
cd /path/to/this/folder
```

### 2. Install everything

Run the setup script. It installs OpenJDK 17, Temurin Java 8, Docker, and Python 3:

```bash
chmod +x practicalsetup.sh
./practicalsetup.sh
```

### 3. Activate the Docker group

Docker was installed and your user was added to the `docker` group, but the group only takes effect in a new session. **Log out and back in**, or run:

```bash
newgrp docker
```

Verify Docker works without `sudo`:

```bash
docker ps
```

### 4. (Optional) Set the Java paths

`control.py` auto-detects the JDKs. If detection misses on your VM, export these before starting:

```bash
export JAVA8_HOME=/usr/lib/jvm/temurin-8-jdk-amd64
export JAVA17_HOME=/usr/lib/jvm/java-17-openjdk-amd64
```

### 5. Start the control server

```bash
python3 control.py
```

On startup it compiles `Server.java` and prints which JDKs and Docker it found. You should see something like:

```
 JDK 8   : /usr/lib/jvm/temurin-8-jdk-amd64
 JDK 17  : /usr/lib/jvm/java-17-openjdk-amd64
 Docker  : yes
 compile : Server.class ready
 Open the dashboard:  http://<this-vm-ip>:9000
```

### 6. Open the dashboard

In a browser go to:

```
http://<VM-IP>:9000
```

The top row of chips shows whether **JDK 8**, **JDK 17**, and **Docker** were detected.

### 7. Try the VM zone (left)

- Click **Run app on Java 8** → the preview shows a Java 8 page on port `8080`.
- Click **Run app on Java 17** → the Java 8 page **disappears** and is replaced by Java 17.

This is the point: one runtime slot, one page at a time.

### 8. Try the Docker zone (right)

- Click **Build both images** (first run takes a minute while it pulls base images).
- Click **Run both containers** → **both** the Java 8 (`8081`) and Java 17 (`8082`) pages appear and stay live together.

Each preview page reports its own `java.version` and shows a "Inside a Docker container" pill.

### 9. Clean up

- **Stop** buttons on the dashboard tear down the VM app / containers.
- Stop the control server with `Ctrl+C` (it stops the VM app on exit).

---

## Optional: run containers from the command line

If you'd rather skip the dashboard for the Docker part:

```bash
chmod +x containersetup.sh
./containersetup.sh
```

This builds both images and starts `java8-container` (→ `8081`) and `java17-container` (→ `8082`), then prints the URLs.

---

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| Dashboard chip says **Docker: missing** | Run `newgrp docker` (or re-login), then `docker ps`. |
| Chips say **JDK 8 / JDK 17: missing** | Set `JAVA8_HOME` / `JAVA17_HOME` (Step 4) and restart `control.py`. |
| Pages don't load in the browser | Open ports `9000`, `8080`, `8081`, `8082` in your firewall / cloud security group. |
| `compile failed` on startup | Ensure a JDK is installed; `control.py` prefers JDK 8's `javac` so the class runs on both 8 and 17. |
| "run failed … did you build the images first?" | Click **Build both images** before **Run both containers**. |

---

## How it works (in one line)

`Server.java` reads its own `java.version` at runtime and renders it. On the VM there's one JVM so you only ever see one version; in Docker each container carries its own JVM, so both versions run at once — which is exactly *why Docker*.

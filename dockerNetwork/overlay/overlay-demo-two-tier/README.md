# Two-tier Swarm demo — browser form on the manager, database on the worker

A web form runs in the **web** service on the **manager** node. Every entry you
submit is written across the overlay network into **Postgres** running in the **db**
service on the **worker** node — and read straight back. You then prove the round-trip
by opening a shell inside the db container on the worker and querying the table.

```
                    ┌─▶ web replica (manager) ─┐
 browser ─:8080─▶ routing mesh                 ├─overlay app-net─▶ db (worker, Postgres)
                    └─▶ web replica (worker)  ─┘                   persistent volume db-data
```

`web` runs as **several replicas spread across both nodes**. Swarm's routing mesh
round-robins requests across them, so the `web_host` column (and the served-by line)
changes as different replicas answer. `db` stays pinned to the worker.

| Service | Node             | Image                | Port  | Role                                   |
|---------|------------------|----------------------|-------|----------------------------------------|
| `web`   | **both** (×N)    | `python:3.11-slim`   | 8080  | serves the form + `/api/messages` JSON |
| `db`    | **worker**       | `postgres:16-alpine` | —     | stores rows in volume `db-data`        |

The web app is injected into the stock Python image as a **Swarm config** (no image
build, no registry). The db has **no published port** — it is reachable only inside the
overlay by the service name `db`, which is the point of the demo.

---

## Files
- `deploy.sh` — self-contained. Copy to the **manager** and run *after* the swarm exists.
  Writes the app, labels nodes, creates the network + config, the worker `db`, and the
  replicated `web` (spread across both nodes). Idempotent. Override count with
  `REPLICAS=N bash deploy.sh`.
- `assets/app.py` — the web tier: stdlib HTTP server + `psycopg2`. Serves the HTML form,
  handles the POST, and exposes `GET /api/messages` (JSON) for curl verification.
- `README.md` — this file.

---

## Prerequisites — form the swarm first (once)

Two VMs with Docker installed are not yet a swarm.

**1. Open these ports *between the two VMs*** (cloud security group / NSG, or `ufw`):

| Port      | Proto     | Purpose                        |
|-----------|-----------|--------------------------------|
| 2377      | TCP       | cluster management             |
| 7946      | TCP + UDP | node-to-node discovery         |
| 4789      | UDP       | overlay data plane (VXLAN)     |
| 8080      | TCP       | the web form (public)          |

If 4789/7946 are blocked, the swarm forms but the web tier can't reach `db` over the
overlay — the page will show "DB not reachable yet".

**2. On VM1 (manager):**
```bash
docker swarm init --advertise-addr <VM1_PRIVATE_IP>
```
Copy the `docker swarm join --token SWMTKN-... <VM1_PRIVATE_IP>:2377` line it prints.

**3. On VM2 (worker):** paste that exact line:
```bash
docker swarm join --token SWMTKN-... <VM1_PRIVATE_IP>:2377
```

**4. Back on VM1, confirm both nodes joined:**
```bash
docker node ls          # expect 2 nodes, one marked Leader
```

---

## Deploy (on the manager, VM1)

```bash
scp deploy.sh user@<VM1_manager>:~
ssh user@<VM1_manager>
bash deploy.sh                  # 4 web replicas by default
# or choose the count:
REPLICAS=6 bash deploy.sh
```
The script auto-labels the manager and the first worker — no manual `docker node update`.
It creates the `web` service with `--replicas` and `--placement-pref 'spread=node.id'`,
so replicas land on **both** nodes.

> First start takes ~20–40s: the web container runs `pip install psycopg2-binary` and
> waits for Postgres to finish initialising. Watch it:
> ```bash
> docker service ls
> docker service ps web db
> docker service logs -f web      # shows "schema ready" when it's up
> ```

---

## Add data in the browser

Open the form:
```
http://<VM1_PUBLIC_IP>:8080
```
Because of Swarm's routing mesh, `http://<VM2_PUBLIC_IP>:8080` works too — either VM's IP
on :8080 reaches the web task on the manager.

Type a **name** and **message**, click **Commit to worker database**. The row appears in
the "Stored rows" table immediately (that list is read live from the worker's Postgres).
The footer's "web served by …" line and each row's **Web host** column show *which
replica* handled the request.

---

## Watch requests spread across web replicas

First, confirm replicas are placed on both nodes (run on the manager):
```bash
docker service ps web
# NODE column should list both VM1 and VM2
```

The cleanest way to see the round-robin is a curl loop — each request is a fresh
connection, so the mesh load-balances every time:
```bash
for i in $(seq 8); do
  curl -s http://<VM1_IP>:8080/api/messages | grep -m1 '"web_host"'
done
# the web_host value cycles through the replica ids
```
Or read it straight from the response header:
```bash
curl -s -D - -o /dev/null http://<VM1_IP>:8080/ | grep -i X-Web-Host
```

Now submit a few entries and each stored row records the replica that inserted it:
```bash
curl -s -o /dev/null -d "name=ada&message=one"   http://<VM1_IP>:8080/add
curl -s -o /dev/null -d "name=ada&message=two"   http://<VM1_IP>:8080/add
curl -s -o /dev/null -d "name=ada&message=three" http://<VM1_IP>:8080/add
curl -s http://<VM1_IP>:8080/api/messages        # see differing web_host per row
```

Scale up or down live and watch the spread change (no redeploy):
```bash
docker service scale web=6
docker service ps web
```

> **In a browser** the `web_host` still varies, but less predictably: browsers reuse a
> keep-alive connection, so several clicks may hit the same replica before switching.
> The curl loop above is the reliable way to see clean round-robin.

---

## Verify the data landed in the worker's database

This is the part that proves cross-node persistence. The db container runs **on VM2**, so
run these **on the worker (VM2)**:

```bash
# 1. find the Postgres container id on this worker
docker ps --filter name=db

# 2. open a shell / psql inside it and read the table
docker exec -it $(docker ps -q --filter name=db) \
  psql -U appuser -d appdb -c "SELECT id, name, message, web_host, created_at FROM messages ORDER BY id;"
```

Expected output (your rows):
```
 id | name  |        message         | web_host      |         created_at
----+-------+------------------------+---------------+----------------------------
  1 | ada   | hello from the browser | web.1.<hash>  | 2026-08-19 04:18:32.148+00
  2 | grace | second entry           | web.1.<hash>  | 2026-08-19 04:18:32.157+00
```

With multiple replicas the `web_host` values will **differ between rows** — each shows the
web container that inserted that row (on either node), while the query itself runs inside
the **db container on the worker**. So a single output proves both that requests were
load-balanced across replicas and that every row landed in the one database on the worker.

Two more cross-node checks (run from the manager, VM1):

```bash
# JSON straight from the web tier — same rows, read from the worker's DB
curl http://<VM1_IP>:8080/api/messages

# the web container resolves and reaches "db" by name over the overlay
docker exec -it $(docker ps -q --filter name=web) \
  python -c "import socket; print('db ->', socket.gethostbyname('db'))"
```

---

## How it fits together
- `web` and `db` share the overlay network `app-net`; Docker's embedded DNS resolves the
  service name `db` to the Postgres task's overlay IP, so `DB_HOST=db` just works.
- `db` publishes no port — it is private to the overlay. Only `web` is public (:8080).
- Postgres data lives in the named volume `db-data` **on the worker**, so it survives
  container restarts and service updates.
- The app auto-creates the `messages` table on startup and retries until Postgres is ready.

## Updating the app
Configs are immutable. Edit `assets/app.py`, then re-run `bash deploy.sh` — it removes the
old services, recreates the `web-app` config, and redeploys. The `db-data` volume (and your
rows) are untouched.

## Cleanup
```bash
docker service rm web db
docker config  rm web-app
docker network rm app-net
docker volume  rm db-data          # run on the WORKER — deletes stored rows
```

## Troubleshooting
- **web stuck in `Preparing`/restarting** → `docker service logs web`. Usually pip has no
  egress, or the manager can't reach Docker Hub for `python:3.11-slim`.
- **page shows "DB not reachable yet"** → overlay ports 4789/7946 blocked between VMs, or
  `db` hasn't finished initialising (give it ~20s; check `docker service ps db`).
- **`db` stuck `Pending`, "no suitable node"** → no node carries `role=worker`. Re-run
  `deploy.sh`, or label manually: `docker node update --label-add role=worker <ID>`.
- **`docker exec` says "no such container" on VM1** → the db task runs on VM2; run the
  verification commands there.

# Docker Swarm overlay demo — beautiful pages for curl **and** browser

Two nginx services on one overlay network:

| Service | Node        | Port  | Browser page          | curl / wget page        |
|---------|-------------|-------|-----------------------|-------------------------|
| `svc1`  | **manager** | 8081  | Container 1 (cyan)    | ANSI terminal card      |
| `svc2`  | **worker**  | 8082  | Container 2 (magenta) | ANSI terminal card      |

The trick: nginx inspects the `User-Agent`. Browsers get the full styled **HTML**;
`curl`/`wget` get an **ANSI-coloured terminal page** (`cli.txt`) that renders in colour
right in your shell. Same URL, different response per client — nothing to remember.

Instead of the fragile `sh -c "echo ... > index.html"` trick, the pages are injected
with **Docker Swarm configs** (immutable, versioned, no rebuild).

## Files
- `deploy.sh` — self-contained. Copy to the **manager** node and run *after the swarm
  exists* (see Prerequisites). Writes all assets, labels the nodes, creates the overlay
  network, the configs, and both services. Idempotent — re-run to update.
- `assets/index1.html`, `assets/index2.html` — browser pages (edit these to taste).
- `assets/cli1.txt`, `assets/cli2.txt` — the ANSI terminal pages.
- `assets/default.conf` — nginx config doing the User-Agent content negotiation.
- `gen_cli.py` — regenerates the ANSI pages if you edit them.

## Prerequisites — form the swarm first (do this once)

`deploy.sh` assumes a working swarm with at least one worker. It does **not** run
`swarm init` / `join` for you. Two VMs with Docker installed are not yet a swarm — form
the cluster first.

**1. Open the ports between the two VMs** (security group / NSG on cloud, or `ufw` on a
bare VM). These are required *between the nodes*, in addition to the app ports 8081/8082
you expose to the outside:

| Port      | Proto     | Purpose                         |
|-----------|-----------|---------------------------------|
| 2377      | TCP       | cluster management (managers)   |
| 7946      | TCP + UDP | node-to-node discovery          |
| 4789      | UDP       | overlay data plane (VXLAN)      |
| 8081/8082 | TCP       | the demo apps (public)          |

If 4789/7946 are blocked, the swarm still forms and services still start, but
cross-node overlay traffic silently fails (e.g. `svc1` can't reach `svc2` by name).

**2. On VM1 (manager):**
```bash
docker swarm init --advertise-addr <VM1_PRIVATE_IP>
```
`--advertise-addr` matters on cloud VMs with more than one interface. This prints a
`docker swarm join --token SWMTKN-... <VM1_PRIVATE_IP>:2377` line — copy it.

**3. On VM2 (worker):** paste the exact line from step 2:
```bash
docker swarm join --token SWMTKN-... <VM1_PRIVATE_IP>:2377
```

**4. Back on VM1, confirm both nodes joined:**
```bash
docker node ls        # expect 2 nodes, one marked Leader
```

## Quick start (after the swarm exists)
```bash
scp deploy.sh user@<VM1_manager>:~
ssh user@<VM1_manager>
bash deploy.sh                 # auto-labels nodes, builds net + configs + services
```
No manual `docker node update` needed — the script labels the manager and the first
worker itself. Then:
```bash
curl http://<VM1_IP>:8081     # svc1 (manager), in colour
curl http://<VM2_IP>:8082     # svc2 (worker), in colour
# browser: http://<VM1_public_IP>:8081  and  http://<VM2_public_IP>:8082 for the HTML pages
```
Swarm's routing mesh means either port also answers on *either* VM's IP
(`http://<VM1_IP>:8082` works too) — it forwards to wherever the task runs.

---

## Manual command reference (equivalent to deploy.sh)

All commands run **on the manager (VM1)** unless noted. The asset files must exist on
VM1 (that's where `docker config create` reads them from).

```bash
# 0. Form the swarm  (skip if already done)
#    On VM1:
docker swarm init --advertise-addr <VM1_PRIVATE_IP>
#    On VM2, paste the join line VM1 printed:
docker swarm join --token SWMTKN-... <VM1_PRIVATE_IP>:2377
#    Back on VM1:
docker node ls

# 1. Overlay network
docker network create --driver overlay --subnet 20.0.0.0/24 my-overlay-net

# quick sanity checks
docker network inspect my-overlay-net | grep -E 'Attachable|Ingress|Subnet'

# 2. Label the nodes  (run on a manager)
docker node ls
docker node update --label-add role=manager <MANAGER_NODE_ID>
docker node update --label-add role=worker  <WORKER_NODE_ID>
docker node inspect <NODE_ID> --format '{{ .Spec.Labels }}'

# 3. Create Swarm configs from the asset files
docker config create ovl-nginx-conf assets/default.conf
docker config create svc1-index     assets/index1.html
docker config create svc1-cli       assets/cli1.txt
docker config create svc2-index     assets/index2.html
docker config create svc2-cli       assets/cli2.txt

# 4. Services — no inline shell, configs are mounted into the container
docker service create --name svc1 \
  --constraint 'node.labels.role==manager' \
  --network my-overlay-net \
  --publish published=8081,target=80 \
  --config source=ovl-nginx-conf,target=/etc/nginx/conf.d/default.conf \
  --config source=svc1-index,target=/usr/share/nginx/html/index.html \
  --config source=svc1-cli,target=/usr/share/nginx/html/cli.txt \
  nginx:alpine

docker service create --name svc2 \
  --constraint 'node.labels.role==worker' \
  --network my-overlay-net \
  --publish published=8082,target=80 \
  --config source=ovl-nginx-conf,target=/etc/nginx/conf.d/default.conf \
  --config source=svc2-index,target=/usr/share/nginx/html/index.html \
  --config source=svc2-cli,target=/usr/share/nginx/html/cli.txt \
  nginx:alpine
```

## Verify

```bash
docker service ls
docker service ps svc1
docker service ps svc2

# service-to-service over the overlay (DNS by service name)
docker exec -it $(docker ps -q --filter name=svc1) sh -c 'wget -qO- http://svc2'
docker exec -it $(docker ps -q --filter name=svc2) sh -c 'wget -qO- http://svc1'

# from the VM
curl http://<private-ip>:8081
curl http://<private-ip>:8082
curl -I http://<private-ip>:8081        # see the X-Served-By (container) header
```

## Updating a page
Configs are immutable. To change a page: edit the asset, then recreate the config and
redeploy the service (the service must be removed before its config can be removed).
`deploy.sh` already does this teardown/recreate for you — just re-run it.

## Cleanup
```bash
docker service rm svc1 svc2
docker config  rm ovl-nginx-conf svc1-index svc1-cli svc2-index svc2-cli
docker network rm my-overlay-net
```

## Notes
- `map` sits at the top of `default.conf`; it is valid there because `conf.d/*.conf`
  is included inside nginx's `http {}` block.
- The browser page prints the container hostname via SSI (`X-Served-By` header carries
  it too), so you can tell replicas apart.
- If your swarm has no worker node, `deploy.sh` pins `svc2` to the manager and warns.

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
- `deploy.sh` — self-contained. Copy to a **manager** node and run. Writes all assets,
  creates the network, labels nodes, creates configs + both services.
- `assets/index1.html`, `assets/index2.html` — browser pages (edit these to taste).
- `assets/cli1.txt`, `assets/cli2.txt` — the ANSI terminal pages.
- `assets/default.conf` — nginx config doing the User-Agent content negotiation.
- `gen_cli.py` — regenerates the ANSI pages if you edit them.

## Quick start
```bash
scp deploy.sh user@<manager-vm>:~
ssh user@<manager-vm>
bash deploy.sh
```
Then:
```bash
curl http://<vm-ip>:8081      # Container 1, in colour
curl http://<vm-ip>:8082      # Container 2, in colour
# open http://<vm-public-ip>:8081  and  :8082 in a browser for the HTML pages
```

---

## Manual command reference (equivalent to deploy.sh)

```bash
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

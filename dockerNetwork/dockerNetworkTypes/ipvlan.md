# Docker IPvlan Demo on Azure (2 NIC VM)

## Lab Topology

```text
Azure VM
├── eth0 = Management NIC (10.0.0.4)
├── eth1 = Container NIC (10.0.0.5)
└── Docker IPvlan Network (L2 Mode)

                 Docker IPvlan Network
                        |
            +-----------+-----------+
            |                       |
        web1 (10.0.0.101)      web2 (10.0.0.102)
            |                       |
      Same Parent Interface (eth1)
      Same Parent MAC Address
```

---

# Objective

This lab demonstrates how Docker IPvlan networking works.

By the end of this lab you will understand:

- Docker IPvlan driver
- IPvlan L2 mode
- Parent Interface
- Static IP assignment
- Container-to-container communication
- Difference between Macvlan and IPvlan

---

# Prerequisites

- Ubuntu Server
- Docker Installed
- Azure VM with **2 NICs**
- Root or sudo access

Verify interfaces

```bash
ip addr
```

Example

```
eth0 → 10.0.0.4
eth1 → 10.0.0.5
```

We'll use **eth1** for the IPvlan network.

---

# Step 1 — Create IPvlan Network

Create an IPvlan network in **L2 Mode**.

```bash
 docker network create -d ipvlan   --subnet=20.0.0.0/24   --gateway=20.0.0.1   -o parent=eth1   -o ipvlan_mode=l2   ipvlan-net
```

Verify

```bash
docker network ls
```

Expected

```
NETWORK ID     NAME
xxxx           ipvlan-net
```

---

# Step 2 — Launch Containers

Create two nginx containers.

Container 1

```bash
docker run -dit \
--name web1 \
--network ipvlan-net \
--ip 20.0.0.101 \
nginx:alpine
```

Container 2

```bash
docker run -dit \
--name web2 \
--network ipvlan-net \
--ip 20.0.0.102 \
nginx:alpine
```

Verify

```bash
docker ps
```

---

# Step 3 — Install Ping Utility

Alpine images don't include ping.

Install it.

```bash
docker exec web1 apk add iputils
docker exec web2 apk add iputils
```

---

# Step 4 — Test Connectivity

Ping from web1 to web2.

```bash
docker exec web1 wget -O- http://20.0.0.102
```

Ping from web2 to web1.

```bash
docker exec web1 wget -O- http://20.0.0.101
```

Expected

```
64 bytes from 20.0.0.102
```

---

# Step 5 — Test HTTP


sudo ip link add ipv-host link eth1 type ipvlan mode l2
sudo ip addr add 20.0.0.200/24 dev ipv-host
sudo ip link set ipv-host up

Access nginx from the host.

```bash
curl http://20.0.0.101
```

```bash
curl http://20.0.0.102
```

Expected

```
Welcome to nginx!
```

---

# Step 6 — Inspect Network

Inspect the Docker IPvlan network.

```bash
docker network inspect ipvlan-net
```

Observe

- Driver = ipvlan
- Parent = eth1
- Mode = l2
- Gateway
- Subnet

---

# Step 7 — View Container Interfaces

Check interface details.

```bash
docker exec web1 ip addr
```

```bash
docker exec web2 ip addr
```

Notice

- Different IP addresses
- Connected to the same IPvlan network
- Traffic exits through the parent interface (eth1)

---

# Step 8 — View Neighbor Table

On the host

```bash
ip neigh
```

Observe neighbor entries for the IPvlan containers.

---

# Step 9 — Capture Packets

Install tcpdump.

```bash
sudo apt update
sudo apt install tcpdump -y
```

Capture packets.

```bash
sudo tcpdump -i eth1
```

Generate traffic.

```bash
docker exec web1 ping -c 4 20.0.0.102
```

Observe ICMP traffic flowing through the parent interface.

---

# Verify Containers

```bash
docker inspect web1
```

```bash
docker inspect web2
```

Verify

```
20.0.0.101
20.0.0.102
```

---

# Verify Network

```bash
docker network inspect ipvlan-net
```

Expected

```
Driver : ipvlan

Mode : L2

Parent : eth1

Subnet : 20.0.0.0/24

Gateway : 20.0.0.1
```

---

# Cleanup

Remove containers

```bash
docker rm -f web1 web2
```

Remove network

```bash
docker network rm ipvlan-net
```

---

# IPvlan Architecture

```text
                Azure Virtual Network
                        |
                  Azure Virtual Switch
                        |
                  eth1 (10.0.0.5)
                        |
              Docker IPvlan (L2 Mode)
                        |
         +--------------+--------------+
         |                             |
  web1 (10.0.0.101)            web2 (10.0.0.102)
         |                             |
      Same Parent Interface (eth1)
      Same Parent MAC Address
```

---

# Macvlan vs IPvlan

| Feature | Macvlan | IPvlan |
|----------|----------|---------|
| Container MAC | Unique | Shared (Parent MAC) |
| Container IP | Unique | Unique |
| Parent Interface | Yes | Yes |
| Switch learns MACs | Yes | No |
| Broadcast Traffic | More | Less |
| Large Scale Deployments | Limited | Excellent |
| Performance | High | Very High |
| CAM Table Usage | Higher | Lower |

---

# Key Learning Points

✔ IPvlan assigns a unique IP to each container.

✔ All containers share the parent interface.

✔ Containers use the parent MAC address.

✔ Switches only learn the parent interface MAC.

✔ IPvlan scales better than Macvlan in large environments.

✔ IPvlan L2 mode allows containers to communicate directly on the Layer 2 network using the parent interface.

---

# Conclusion

In this lab you learned how to:

- Create an IPvlan network
- Configure L2 mode
- Launch containers with static IP addresses
- Verify container communication
- Capture traffic with tcpdump
- Compare IPvlan with Macvlan
- Understand why IPvlan is preferred for high-density container deployments
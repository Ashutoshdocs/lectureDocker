# Docker Macvlan Demo on Azure (2 NIC VM)

## Lab Topology

``` text
Azure VM
├── eth0 = Management NIC (10.0.0.4)
├── eth1 = Container NIC (10.0.0.5)
└── mac0 = Host Macvlan Interface (10.0.0.200)

                 Docker Macvlan Network
                        |
            +-----------+-----------+
            |                       |
        web1 (10.0.0.101)     web2 (10.0.0.102)
```

## Prerequisites

-   Ubuntu VM in Azure
-   Docker installed
-   Two NICs attached
-   Subnet: `10.0.0.0/24`
-   Gateway: `10.0.0.1`

------------------------------------------------------------------------

## 1. Verify Interfaces

``` bash
ip -br addr
```

## 2. Verify Docker

install docker

## 3. Cleanup Previous Demo

verify docker installation

## 4. Create Macvlan Network

``` bash
docker network create -d macvlan \
--subnet=10.0.0.0/24 \
--gateway=10.0.0.1 \
-o parent=eth1 \
macvlan-net
```

Verify:

``` bash
docker network inspect macvlan-net
```

## 5. Start Containers

``` bash
docker run -d \
--name web1 \
--network macvlan-net \
--ip 10.0.0.101 \
nginx

docker run -d \
--name web2 \
--network macvlan-net \
--ip 10.0.0.102 \
nginx
```

## 6. Verify

``` bash
docker ps

docker inspect -f '{{.Name}} -> {{range.NetworkSettings.Networks}}{{.IPAddress}}{{end}}' web1 web2
```

## 7. Container to Container

``` bash
docker exec web1 curl http://10.0.0.102
```

## 8. Host Cannot Reach Container (Expected)

``` bash
ping -c 4 10.0.0.101
```

## 9. Create Host Macvlan Interface

``` bash
sudo ip link add mac0 link eth1 type macvlan mode bridge
sudo ip addr add 10.0.0.200/24 dev mac0
sudo ip link set mac0 up
```

Verify:

``` bash
ip -br addr
```

## 10. Host to Container

``` bash
ping -c 4 10.0.0.101
ping -c 4 10.0.0.102

curl http://10.0.0.101
curl http://10.0.0.102
```

## 11. Inspect Networking

``` bash
docker network inspect macvlan-net
ip route
ip link
```

## 12. Cleanup

``` bash
docker rm -f web1 web2
docker network rm macvlan-net
sudo ip link del mac0
```

## Notes

-   Containers receive their own IP addresses on the Macvlan network.
-   Containers can communicate with each other.
-   The host requires a host-side Macvlan interface (`mac0`) to
    communicate with Macvlan containers.
-   In Azure, other VMs generally cannot directly reach Macvlan
    container IPs because Azure virtual networking does not expose
    multiple MAC addresses behind a VM NIC.

#!/bin/bash
set -e

echo "========================================"
echo "Building Docker Images"
echo "========================================"

docker build -t app-java8 -f Dockerfile.java8 .

docker build -t app-java17 -f Dockerfile.java17 .

echo
echo "========================================"
echo "Starting Containers"
echo "========================================"

docker run -d \
  --name java8-container \
  -p 8081:8080 \
  -e PORT=8080 \
  app-java8

docker run -d \
  --name java17-container \
  -p 8082:8080 \
  -e PORT=8080 \
  app-java17

echo
echo "========================================"
echo "Running Containers"
echo "========================================"

docker ps

echo
echo "========================================"
echo "Access the Applications"
echo "========================================"

echo "Java 8 : http://<VM-IP>:8081"
echo "Java17 : http://<VM-IP>:8082"

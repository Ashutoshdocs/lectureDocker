#!/bin/bash
set -e

echo "========================================"
echo " Installing Java 8, Java 17, Docker"
echo " Python on Ubuntu 24.04"
echo "========================================"

sudo apt update

echo "Installing prerequisites..."
sudo apt install -y \
    curl \
    wget \
    git \
    unzip \
    software-properties-common \
    apt-transport-https \
    ca-certificates \
    gnupg \
    lsb-release

#################################################
# Install Java 17
#################################################

echo
echo "Installing OpenJDK 17..."
sudo apt install -y openjdk-17-jdk

#################################################
# Install Java 8 (Temurin)
#################################################

echo
echo "Installing Temurin Java 8..."

wget -qO - https://packages.adoptium.net/artifactory/api/gpg/key/public \
| sudo gpg --dearmor -o /usr/share/keyrings/adoptium.gpg

echo "deb [signed-by=/usr/share/keyrings/adoptium.gpg] https://packages.adoptium.net/artifactory/deb noble main" \
| sudo tee /etc/apt/sources.list.d/adoptium.list

sudo apt update
sudo apt install -y temurin-8-jdk

#################################################
# Install Docker
#################################################

echo
echo "Installing Docker..."

sudo apt install -y docker.io

sudo systemctl enable docker
sudo systemctl start docker

sudo usermod -aG docker $USER

#################################################
# Install Python
#################################################

echo
echo "Installing Python..."

sudo apt install -y \
    python3 \
    python3-pip \
    python3-venv

#################################################
# JAVA HOME
#################################################

JAVA8_HOME=$(dirname $(dirname $(readlink -f $(which javac | head -1))))

echo
echo "Searching Java installations..."

find /usr/lib/jvm -maxdepth 1 -type d

#################################################
# Verification
#################################################

echo
echo "========================================"
echo "Installed Versions"
echo "========================================"

echo
echo "Java 17"
java -version

echo
echo "Java 8"
/usr/lib/jvm/temurin-8-jdk-amd64/bin/java -version

echo
echo "Docker"
docker --version

echo
echo "Python"
python3 --version

echo
echo "Pip"
pip3 --version

echo
echo "========================================"
echo "IMPORTANT"
echo "========================================"
echo
echo "Log out and log back in"
echo "OR execute:"
echo
echo "newgrp docker"
echo
echo "Then verify:"
echo "docker ps"
echo
echo "Set JAVA paths before running control.py if required:"
echo
echo "export JAVA8_HOME=/usr/lib/jvm/temurin-8-jdk-amd64"
echo "export JAVA17_HOME=/usr/lib/jvm/java-17-openjdk-amd64"
echo
echo "python3 control.py"

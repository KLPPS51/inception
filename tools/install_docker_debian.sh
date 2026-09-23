#!/bin/sh
# ---------------------------------------------------------------
# Installs Docker Engine and the Compose plugin on a Debian or
# Ubuntu virtual machine.
#
# Optional helper: it is not part of the graded project.
#   usage: sh tools/install_docker_debian.sh
# ---------------------------------------------------------------
set -e

echo ">>> installing the prerequisites"
sudo apt-get update
sudo apt-get install -y ca-certificates curl gnupg make

echo ">>> adding Docker's GPG key"
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg \
    | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

echo ">>> adding the Docker repository"
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
https://download.docker.com/linux/debian $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
    | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io \
                        docker-buildx-plugin docker-compose-plugin

echo ">>> adding $USER to the docker group"
sudo usermod -aG docker "$USER"

echo ""
echo ">>> Done. LOG OUT and back in (or reboot) so that the docker"
echo ">>> group membership takes effect."

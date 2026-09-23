#!/bin/sh
# ---------------------------------------------------------------
# Installs Docker Engine and the Compose v2 plugin on a Debian or
# Ubuntu virtual machine, from Docker's official repository.
#
# The distribution packages (docker.io, docker-compose) are removed
# first: they ship an old engine and no Compose v2 plugin, and they
# conflict with docker-ce.
#
# Optional helper: it is not part of the graded project.
#   usage: sh tools/install_docker_debian.sh
# ---------------------------------------------------------------
set -e

# ---- Detect the distribution --------------------------------
# download.docker.com serves a different repository for Debian and
# for Ubuntu, so read the id instead of assuming one.
. /etc/os-release
case "$ID" in
    debian|ubuntu)
        DISTRO="$ID"
        ;;
    *)
        # Derive from ID_LIKE for derivatives such as Linux Mint.
        case "$ID_LIKE" in
            *ubuntu*) DISTRO="ubuntu" ;;
            *debian*) DISTRO="debian" ;;
            *)
                echo "Unsupported distribution: $ID" >&2
                echo "Install Docker manually: https://docs.docker.com/engine/install/" >&2
                exit 1
                ;;
        esac
        ;;
esac
echo ">>> detected $DISTRO $VERSION_CODENAME"

# ---- Remove the conflicting distribution packages -----------
echo ">>> removing the distribution's Docker packages, if any"
for pkg in docker.io docker-doc docker-compose podman-docker containerd runc
do
    sudo apt-get remove -y "$pkg" 2>/dev/null || true
done

# ---- Prerequisites ------------------------------------------
echo ">>> installing the prerequisites"
sudo apt-get update
sudo apt-get install -y ca-certificates curl gnupg make

# ---- Docker's GPG key ---------------------------------------
echo ">>> adding Docker's GPG key"
sudo install -m 0755 -d /etc/apt/keyrings
sudo rm -f /etc/apt/keyrings/docker.gpg
curl -fsSL "https://download.docker.com/linux/$DISTRO/gpg" \
    | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

# ---- Docker's repository ------------------------------------
echo ">>> adding the Docker repository"
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
https://download.docker.com/linux/$DISTRO $VERSION_CODENAME stable" \
    | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# ---- Engine and Compose plugin ------------------------------
echo ">>> installing Docker Engine and the Compose plugin"
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io \
                        docker-buildx-plugin docker-compose-plugin

sudo systemctl enable --now docker

echo ">>> adding $USER to the docker group"
sudo usermod -aG docker "$USER"

echo ""
echo ">>> Installed:"
docker --version
docker compose version
echo ""
echo ">>> Now LOG OUT and back in (or reboot) so that the docker group"
echo ">>> membership takes effect, then run: make"

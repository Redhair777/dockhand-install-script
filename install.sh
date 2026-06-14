#!/bin/bash
set -e

REQUIRED_NETWORK="pangolin_frontend"
COMPOSE_URL="https://raw.githubusercontent.com/Redhair777/dockhand-install-script/main/docker-compose.yml"
INSTALL_DIR="$(pwd)/dockhand"

check_docker() {
  if ! command -v docker &>/dev/null; then
    echo "ERROR: Docker is not installed. Please install Docker first."
    exit 1
  fi
  if ! docker info &>/dev/null; then
    echo "ERROR: Docker daemon is not running or insufficient permissions."
    exit 1
  fi
}

check_network() {
  if ! docker network ls --format '{{.Name}}' | grep -q "^${REQUIRED_NETWORK}$"; then
    echo "ERROR: Docker network '${REQUIRED_NETWORK}' not found. Please complete the Pangolin installation first."
    exit 1
  fi
}

setup_directory() {
  if [[ -d "$INSTALL_DIR" ]]; then
    echo "Directory $INSTALL_DIR already exists. Skipping creation."
  else
    mkdir -p "$INSTALL_DIR"
    echo "Created directory: $INSTALL_DIR"
  fi
}

download_compose() {
  echo "Downloading docker-compose.yml..."
  curl -fsSL "$COMPOSE_URL" -o "${INSTALL_DIR}/docker-compose.yml"
  echo "docker-compose.yml downloaded successfully."
}

pull_images() {
  echo "Pulling Docker images..."
  cd "$INSTALL_DIR"
  docker compose pull
  echo "Images pulled successfully."
}

start_services() {
  echo "Starting Dockhand..."
  cd "$INSTALL_DIR"
  docker compose up -d
  echo "Dockhand is running."
}

check_existing_install() {
  if docker ps -a --format '{{.Names}}' | grep -q "^dockhand$"; then
    echo "An existing Dockhand installation was detected."
    echo ""
    echo "What would you like to do?"
    echo "  1) Update    — pull latest image and restart (data preserved)"
    echo "  2) Reinstall — remove everything and start fresh (data will be lost)"
    echo "  3) Abort     — exit without making changes"
    echo ""
    read -rp "Enter choice [1/2/3]: " choice
    case "$choice" in
      1)
        cd "$INSTALL_DIR"
        docker compose pull
        docker compose up -d
        echo "Dockhand updated successfully."
        exit 0
        ;;
      2)
        cd "$INSTALL_DIR"
        docker compose down -v --remove-orphans
        echo "Existing installation removed. Continuing with fresh install..."
        ;;
      3)
        echo "Aborted. No changes made."
        exit 0
        ;;
      *)
        echo "Invalid choice. Aborting."
        exit 1
        ;;
    esac
  fi
}

main() {
  echo "Starting Dockhand installation..."
  echo ""
  check_docker
  check_network
  check_existing_install
  setup_directory
  download_compose
  pull_images
  start_services
  echo ""
  echo "Installation complete!"
  echo "Next step: configure your reverse proxy in Pangolin pointing to dockhand:3000"
}

main

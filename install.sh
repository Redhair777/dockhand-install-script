#!/usr/bin/env bash

# Set bash "unofficial strict mode"
set -euo pipefail
IFS=$'\n\t'

# Global variables
COMPOSE_URL="https://raw.githubusercontent.com/Redhair777/dockhand-install-script/main/docker-compose.yml"

# Logging utility functions ----------------

# ANSI color codes
color_blue="\033[0;34m"
color_green="\033[0;32m"
color_yellow="\033[0;33m"
color_red="\033[0;31m"
color_bold="\033[1m"
color_reset="\033[0m"

function log::info
{
  printf "${color_bold}[%s]${color_reset} [${color_blue}INFO${color_reset}] %s\n" "$(date +%H:%M:%S)" "$1"
}

function log::success
{
  printf "${color_bold}[%s]${color_reset} [${color_green}SUCCESS${color_reset}] %s\n" "$(date +%H:%M:%S)" "$1"
}

function log::warn
{
  printf "${color_bold}[%s]${color_reset} [${color_yellow}WARN${color_reset}] %s\n" "$(date +%H:%M:%S)" "$1"
}

function log::error
{
  printf "${color_bold}[%s]${color_reset} [${color_red}ERROR${color_reset}] %s\n" "$(date +%H:%M:%S)" "$1" >&2
}

# Business logic functions ----------------

function util::command_exists
{
  command -v "$1" &>/dev/null
}

function ensure_docker_running
{
  log::info "Checking Docker installation and status..."

  # Ensure Docker is installed
  if ! util::command_exists docker
  then
    log::error "Docker is not installed. Please install Docker first."
    exit 1
  fi

  # Ensure Docker daemon is running and user has permissions
  if ! docker info &>/dev/null
  then
    log::error "Docker daemon is not running or insufficient permissions."
    exit 1
  fi

  # Ensure the required Docker network exists
  local required_network="pangolin_frontend"
  if ! docker network ls --format '{{.Name}}' | grep -q "^${required_network}$"
  then
    log::error "Docker network '${required_network}' not found. Please complete the Pangolin installation first."
    exit 1
  fi

  log::success "Docker is installed, running, and the required network '${required_network}' exists."
}

function install_and_start_dockhand
{
  log::info "Installing Dockhand..."

  log::info "Setting up installation directory..."
  local target_user="${SUDO_USER:-$USER}"
  local dockhand_install_dir
  dockhand_install_dir="$(getent passwd "$target_user" | cut -d: -f6)/dockhand"
  if ! mkdir -p "$dockhand_install_dir"
  then
    log::error "Failed to create installation directory: ${dockhand_install_dir}"
    exit 1
  fi
  log::success "Installation directory set to: ${dockhand_install_dir}"


  log::info "Downloading docker-compose.yml..."
  local compose_tmp
  compose_tmp="$(mktemp "${dockhand_install_dir}/.compose.XXXXXX")"
  if ! curl -fsSL "$COMPOSE_URL" -o "$compose_tmp"
  then
    rm -f "$compose_tmp"
    log::error "Failed to download docker-compose.yml."
    exit 1
  fi
  if ! mv "$compose_tmp" "${dockhand_install_dir}/docker-compose.yml"
  then
    rm -f "$compose_tmp"
    log::error "Failed to move docker-compose.yml."
    exit 1
  fi
  log::success "docker-compose.yml downloaded successfully into ${dockhand_install_dir}"


  log::info "Pulling Docker images from docker-compose.yml..."
  if ! (cd "$dockhand_install_dir" && docker compose pull)
  then
    log::error "Failed to pull Docker images."
    exit 1
  fi
  log::success "Docker images pulled successfully."


  log::info "Starting Dockhand services..."
  if ! (cd "$dockhand_install_dir" && docker compose up -d --remove-orphans)
  then
    log::error "Failed to start Dockhand services."
    exit 1
  fi
  log::success "Dockhand services started successfully."
}

# Main processing starts here ----------------

log::info "Starting Dockhand installation..."
printf "\n" # Add a newline for better readability

ensure_docker_running
install_and_start_dockhand

printf "\n" # Add a newline for better readability
log::success "Installation complete!"
log::info "Next step: configure your reverse proxy in Pangolin pointing to dockhand:3000"

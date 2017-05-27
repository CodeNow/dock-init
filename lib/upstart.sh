#!/bin/bash

source "${DOCK_INIT_BASE}/lib/util/log.sh"
source "${DOCK_INIT_BASE}/lib/util/rollbar.sh"

upstart::restart_docker() {
  log::info "Starting Docker"
  rollbar::fatal_trap \
    "Dock-Init: Failed to Start Docker" \
    "Server was unable to start service."
  systemctl restart docker
  rollbar::clear_trap

  log::info "Waiting for Docker"
  local attempt=1
  local timeout=.5
  while [ ! -e /var/run/docker.sock ]
  do
    log::info "Docker Sock N/A ($attempt)"
    sleep $timeout
    attempt=$(( attempt + 1 ))
  done
}

#!/bin/bash

# Functions for generating service upstart scripts from consul templates and
# upstarting services for the dock.
# @author Ryan Sandor Richards
# @author Bryan Kendall

source "${DOCK_INIT_BASE}/lib/util/log.sh"
source "${DOCK_INIT_BASE}/lib/util/rollbar.sh"

# Start dockers (due to manual override now set in /etc/init)
upstart::start_docker() {
  log::info "Starting Docker"
  rollbar::fatal_trap \
    "Dock-Init: Failed to Start Docker" \
    "Server was unable to start service."
  service docker start
  rollbar::clear_trap

  log::info "Waiting for Docker"
  local attempt=1
  local timeout=.5
  while [ ! -e /var/run/docker.sock ]
  do
    log::info "Docker Sock N/A ($attempt)"
    local title="Dock-Init: Cannot Reach Docker"
    local message="Attempting to reach Docker and failing."
    local data="{\"docker_host\":\"/var/run/docker.sock\",\"attempt\":\"${attempt}\"}"
    rollbar::report_warning "${title}" "${message}" "$data"
    sleep $timeout
    attempt=$(( attempt + 1 ))
  done
}

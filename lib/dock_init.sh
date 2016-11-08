#!/bin/bash

# Entry-point script for dock initialization. Simply includes the `lib/dock.sh`
# library and calls the master initialization function.
#
# NOTE This script will automatically update the `lib/` directory before
#      the dock is initialized. This means that this script itself will not be
#      automatically updated. To do so a new AMI must be baked.
#
# @author Ryan Sandor Richards

export DOCK_INIT_BASE=/opt/runnable/dock-init
export CONSUL_HOSTNAME=10.4.5.144
export HOST_IP=$(hostname -i)
export CONSUL_PORT=8500
export DONT_DELETE_KEYS=true
export USE_EXIT=true
export LOG_LEVEL=trace
export FETCH_ORIGIN_ALL=true

if [ -z "${CONSUL_PORT+x}" ]; then
  export CONSUL_PORT=8500
else
  export CONSUL_PORT
fi

source "${DOCK_INIT_BASE}/lib/consul.sh"
source "${DOCK_INIT_BASE}/lib/util/log.sh"
source "${DOCK_INIT_BASE}/lib/util/rollbar.sh"
source "${DOCK_INIT_BASE}/lib/util/backoff.sh"

# Executes a command using an ssh agent with the id_rsa_runnabledock key
# @param $1 action Comand to execute
ssh_execute() {
  local action="$1"
  ssh-agent bash -c "ssh-add key/id_rsa_runnabledock; $action"
}

# Automatically updates dock-init to the version given in consul, if needed.
# After consul has been updated this executes the main script.
auto_update() {
  log::info "Updating dock-init"
  consul::connect

  log::trace 'Fetching dock-init version from consul...'
  local version=$(consul::get '/dock-init/version')
  log::info "dock-init version found: $version"

  log::trace "moving to dock init base directory ($DOCK_INIT_BASE)"
  cd "$DOCK_INIT_BASE"

  log::trace "fetching all from repository"
  if [[ "$FETCH_ORIGIN_ALL" != "" ]]; then
    ssh_execute "git fetch origin $version"
  else
    ssh_execute "git fetch origin"
  fi

  log::info "Checking out dock-init version: $version"
  ssh_execute "git checkout $version"
}

# Initializes the dock
main() {
  source "${DOCK_INIT_BASE}/lib/dock.sh"
  dock::init
}

# Attempt to auto-update then initialize the dock
backoff auto_update && main

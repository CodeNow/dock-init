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
export HOST_IP=$(hostname -i)

if [ -z "${CONSUL_PORT+x}" ]; then
  export CONSUL_PORT=8500
else
  export CONSUL_PORT
fi

source "${DOCK_INIT_BASE}/lib/consul.sh"
source "${DOCK_INIT_BASE}/lib/aws.sh"
source "${DOCK_INIT_BASE}/lib/dock.sh"
source "${DOCK_INIT_BASE}/lib/container.sh"
source "${DOCK_INIT_BASE}/lib/util/log.sh"

# Initializes the dock
main() {
  consul::connect
  consul::get_environment
  consul::configure_consul_template
  aws::get_org_id
  dock::set_hostname
  dock::set_config_org
  container::start
  log::info "Init Done!"
}

main

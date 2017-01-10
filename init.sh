#!/bin/bash

# Entry-point script for dock initialization. Simply includes the `lib/dock.sh`
# library and calls the master initialization function.
# @author Ryan Sandor Richards

export DOCK_INIT_BASE=/opt/runnable/dock-init
export HOST_IP=$(hostname -i)

if [ -z "${CONSUL_PORT+x}" ]; then
  export CONSUL_PORT=8500
else
  export CONSUL_PORT
fi

if [ -z "${CONSUL_HOSTNAME+x}" ]; then
  export CONSUL_HOSTNAME=10.4.5.144
else
  export CONSUL_HOSTNAME
fi

export DOCKER_NETWORK=172.17.0.0/16

source "${DOCK_INIT_BASE}/lib/consul.sh"
source "${DOCK_INIT_BASE}/lib/aws.sh"
source "${DOCK_INIT_BASE}/lib/dock.sh"
source "${DOCK_INIT_BASE}/lib/container.sh"
source "${DOCK_INIT_BASE}/lib/iptables.sh"
source "${DOCK_INIT_BASE}/lib/util/log.sh"

# Initializes the dock
main() {
  consul::connect
  consul::get_environment
  consul::configure_consul_template
  dock::generate_certs
  aws::get_org_id
  dock::set_hostname
  dock::set_config_org
  container::start
  # rules must be run after docker has started
  iptables::run_rules
  log::info "Init Done!"
}

main

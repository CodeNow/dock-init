#!/bin/bash

# Entry-point script for dock initialization. Simply includes the `lib/dock.sh`
# library and calls the master initialization function.
# @author Ryan Sandor Richards

export DOCK_INIT_BASE=/opt/runnable/dock-init
export HOST_IP=$(hostname -i)
source "${DOCK_INIT_BASE}/lib/util/log.sh"
source "${DOCK_INIT_BASE}/lib/consul.sh"
source "${DOCK_INIT_BASE}/lib/aws.sh"
source "${DOCK_INIT_BASE}/lib/dock.sh"
source "${DOCK_INIT_BASE}/lib/vault.sh"
source "${DOCK_INIT_BASE}/lib/container.sh"
source "${DOCK_INIT_BASE}/lib/cleanup.sh"
source "${DOCK_INIT_BASE}/lib/kubernetes.sh"

# Initializes the dock
main() {
  # Make sure to setup the exit trap first so we never have a dock with creds hanging about
  cleanup::set_exit_trap
  consul::connect
  consul::get_environment
  consul::configure_consul_template
  dock::generate_certs
  aws::get_org_ids
  dock::set_config_org
  vault::store_private_registry_token
  k8::set_node_lables
  dock::set_hostname
  container::start
  log::info "Init Done!"
}

main

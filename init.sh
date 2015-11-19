#!/bin/bash

source ./lib/backoff.sh
source ./lib/log.sh
source ./lib/rollbar.sh
source ./lib/aws.sh
source ./lib/consul.sh
source ./lib/dockinit.sh

# This is the primary dock initialization script that is executed when a dock
# is provisioned via shiva. It calls the `upstart.sh` script and attempts to
# upstart services. If the upstart fails, it will retry (indefinitely with an
# exponential backoff.
#
# @author Ryan Sandor Richards
# @author Bryan Kendall

# Export the base directory for dock-init
export DOCK_INIT_BASE=/opt/runnable/dock-init

# provided by the user script that runs this script
export CONSUL_HOSTNAME

# Paths to the cert and upstart scripts
export CERT_SCRIPT=${DOCK_INIT_BASE}/cert.sh
export UPSTART_SCRIPT=${DOCK_INIT_BASE}/upstart.sh

# Set empty environment is until we get the node env from consul
export environment=""

# Initializes the dock
main() {
  log::info "environment:\n$(env)"
  dockinit::set_cleanup_trap

  # Connect to and configure consul then collect various information we need
  aws::get_local_ip
  consul::connect
  consul::get_environment
  consul::configure_consul_template
  consul::start_vault
  aws::get_org_id

  # Now that we have everything we need and consul is ready, initialize the dock
  dockinit::set_config_org
  dockinit::generate_upstart_scripts
  dockinit::generate_certs
  dockinit::generate_etc_hosts
  dockinit::set_registry_host
  dockinit::remove_docker_key_file
  dockinit::start_docker
  dockinit::attempt_upstart
  log::info "Init Done!"

  # Perform any cleanup tasks now that the dock is up and running
  dockinit::cleanup::stop_vault
}

# Get Action...
main

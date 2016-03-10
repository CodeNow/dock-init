#!/bin/bash

# This is the primary dock initialization module that is executed via the
# `init.sh` script when a dock is provisioned via shiva. It loads various
# libraries (located in `lib/`)` and composes the exposed methods together to
# fully initialize, start, and register a dock.
#
# @author Ryan Sandor Richards
# @author Bryan Kendall
# @module dock

source "${DOCK_INIT_BASE}/lib/aws.sh"
source "${DOCK_INIT_BASE}/lib/cert.sh"
source "${DOCK_INIT_BASE}/lib/consul.sh"
source "${DOCK_INIT_BASE}/lib/upstart.sh"

source "${DOCK_INIT_BASE}/lib/util/log.sh"
source "${DOCK_INIT_BASE}/lib/util/rollbar.sh"
source "${DOCK_INIT_BASE}/lib/util/backoff.sh"

# An "on exit" trap to clean up sensitive keys and files on the dock itself.
# Note that this will have no effect if the `DONT_DELETE_KEYS` environment has
# been set (useful for testing)
dock::cleanup::exit_trap() {
  # Delete the keys unless the `DO_NOT_DELETE` flag is set
  if [[ "${DONT_DELETE_KEYS}" == "" ]]; then
    log::info '[CLEANUP TRAP] Removing Keys'
    rm -f "${CERT_PATH}"/ca-key.pem \
          "${CERT_PATH}"/pass \
          "${DOCK_INIT_BASE}"/consul-resources/vault/**/auth-token \
          "${DOCK_INIT_BASE}"/consul-resources/vault/**/token-* \
          "${DOCK_INIT_BASE}"/key/rollbar.token
  fi
}

# Sets the cleanup trap for the entire script
dock::cleanup::set_exit_trap() {
  log::info "Setting key cleanup trap"
  trap 'dock::cleanup::exit_trap' EXIT
}

# Sets the value of `$ORG_ID` as the org label in the docker configuration
dock::set_config_org() {
  log::info "Setting organization id in docker configuration"
  echo DOCKER_OPTS=\"\$DOCKER_OPTS --label org="${ORG_ID}"\" >> /etc/default/docker
}

# adds org to hostname
dock::set_hostname() {
  log::info "Adding organization id in hostname"
  hostname `hostname`."${ORG_ID}"
}

# Backoff method for generating host certs
dock::generate_certs_backoff() {
  rollbar::warning_trap \
    "Dock-Init: Generate Host Certificate" \
    "Failed to generate Docker Host Certificate."
  cert::generate
  rollbar::clear_trap
}

# Generates host certs for the dock
dock::generate_certs() {
  log::info "Generating Host Certificate"
  backoff dock::generate_certs_backoff
}

# Generates the correct /etc/hosts file for the dock
dock::generate_etc_hosts() {
  log::info "Generating /etc/hosts"

  rollbar::fatal_trap \
    "Dock-Init: Failed to Host Registry Entry" \
    "Consule-Template was unable to realize the given template."

  local template=''
  template+="$DOCK_INIT_BASE/consul-resources/templates/hosts-registry.ctmpl"
  template+=":$DOCK_INIT_BASE/hosts-registry.txt"
  consul-template \
    -config="${DOCK_INIT_BASE}"/consul-resources/template-config.hcl \
    -once \
    -template="${template}"

  rollbar::clear_trap
}

# Sets the correct registry.runnable.com host
dock::set_registry_host() {
  local registry_host=$(cat "$DOCK_INIT_BASE/hosts-registry.txt")
  log::info "Set registry host: $registry_host"
  echo "$registry_host" >> /etc/hosts
}

# Remove docker key file so it generates a unique id
dock::remove_docker_key_file() {
  log::info "Removing docker key.json"
  rm -f /etc/docker/key.json
}

# Master function for performing all tasks and initializing the dock
dock::init() {
  # Setup the exit trap and rollbar
  dock::cleanup::set_exit_trap
  rollbar::init

  # Connect to and configure consul then collect various information we need
  consul::connect
  consul::get_environment
  consul::configure_consul_template
  aws::get_org_id

  # Now that we have everything we need and consul is ready, initialize the dock
  dock::set_hostname
  dock::set_config_org
  dock::generate_certs
  dock::generate_etc_hosts
  dock::set_registry_host
  dock::remove_docker_key_file
  upstart::start

  # Give the all clear message!
  log::info "Init Done!"
}

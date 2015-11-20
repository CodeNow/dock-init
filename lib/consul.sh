#!/bin/bash

source ./lib/log.sh
source ./lib/rollbar.sh
source ./lib/vault.sh

# Consul routines used by the main `init.sh` dock-init script.
# @author Ryan Sandor Richards
# @module consul

# Backoff andler for ensuring the dock can connect to consul
# @param $1 attempt The attempt number passed by the backoff routine below
consul::connect_backoff() {
  local attempt=${1}
  log::info "Trying to reach consul at $CONSUL_HOSTNAME:8500 (attempt: $attempt)"
  rollbar::warning_trap \
    "Dock-Init: Cannot Reach Consul Server" \
    "Attempting to reach Consul and failing."
  curl http://"${CONSUL_HOSTNAME}":8500/v1/status/leader 2>&1
  rollbar::clear_trap
}

# Ensures that consul is available to the dock via curl
consul::connect() {
  backoff consul::connect_backoff
}

# Connects to consul and gets the environment for the dock
consul::get_environment() {
  rollbar::fatal_trap \
    "Dock-Init: Cannot get Environment" \
    "Unable to reach Consul and retrieve Environment."
  environment=$(curl http://"${CONSUL_HOSTNAME}":8500/v1/kv/node/env 2> /dev/null | jq --raw-output ".[0].Value" | base64 --decode)
  export environment
  rollbar::clear_trap
}

# Configures the `consul-template` utility
consul::configure_consul_template() {
  log::info "configuring consul-template"
  rollbar::fatal_trap \
    "Dock-Init: Failed to Render Template Config" \
    "Consul-Template was unable to realize the given template."

  local template="$DOCK_INIT_BASE/consul-resources/templates/"
  template+="template-config.hcl.ctmpl"
  template+=":$DOCK_INIT_BASE/consul-resources/template-config.hcl"

  consul-template -once -template="$template"

  rollbar::clear_trap
}

# Starts vault so we can grab secret information such as AWS keys, etc.
consul::start_vault() {
  log::info "Starting Vault"
  rollbar::fatal_trap \
    "Dock-Init: Failed to run start-vault.sh" \
    "Vault was unable to start."
  vault::start
  rollbar::clear_trap
}

#!/bin/bash

source "${DOCK_INIT_BASE}/lib/util/log.sh"
source "${DOCK_INIT_BASE}/lib/util/rollbar.sh"

# Consul routines used by the main `init.sh` dock-init script.
# @author Ryan Sandor Richards
# @module consul

# Shoot yourself in the head if `jq` does not work.
consul::test_jq() {
  jq > /dev/null 2>&1 
  if [ "0" -ne "${?}" ] ; then
      log::fatal "This server does not have a functioning `jq`, dying."
  fi
  rollbar::fatal_trap "Dock-Init: Host has non-working jq executable."
  rollbar::clear_trap
  return 1
}

# Backoff handler for ensuring the dock can connect to consul
# @param $1 attempt The attempt number passed by the backoff routine below
consul::connect_backoff() {
  local attempt=${1}
  local host="$CONSUL_HOSTNAME:$CONSUL_PORT"
  log::info "Trying to reach consul at $host (attempt: $attempt)"
  rollbar::warning_trap \
    "Dock-Init: Cannot Reach Consul Server" \
    "Attempting to reach Consul and failing."
  curl "http://$host/v1/status/leader" 2>&1
  rollbar::clear_trap
}

# Ensures that consul is available to the dock via curl
consul::connect() {
  backoff consul::connect_backoff
}

# Echos a value from consul foer the given keypath
# @param $1 keypath Keypath for the value to get from consul
consul::get() {
  # Strip leading slashes so it works with both '/my/path' and 'my/path'
  local path=$(echo "$1" | sed 's/^\///')
  local url="http://$CONSUL_HOSTNAME:$CONSUL_PORT/v1/kv/$path"
  curl --silent "$url" 2> /dev/null | \
    jq --raw-output ".[0].Value" | \
    base64 --decode
}

# Connects to consul and gets the environment for the dock
consul::get_environment() {
  rollbar::fatal_trap \
    "Dock-Init: Cannot get Environment" \
    "Unable to reach Consul and retrieve Environment."
  environment=$(consul::get 'node/env')
  export environment
  rollbar::clear_trap
}

# Configures the `consul-template` utility
consul::configure_consul_template() {
  log::info "configuring consul-template"
  rollbar::fatal_trap \
    "Dock-Init: Failed to Render Template Config" \
    "Consul-Template was unable to realize the given template."

  # expose VAULT_TOKEN for consul-template config
  local NODE_ENV=$(consul::get node/env)
  local token_path="${DOCK_INIT_BASE}/consul-resources/vault/${NODE_ENV}"
  VAULT_TOKEN=$(cat "${token_path}"/auth-token)
  export VAULT_TOKEN

  local template="$DOCK_INIT_BASE/consul-resources/templates/"
  template+="template-config.hcl.ctmpl"
  template+=":$DOCK_INIT_BASE/consul-resources/template-config.hcl"

  consul-template -once -template="$template"

  rollbar::clear_trap
}

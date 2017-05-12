#!/bin/bash

source "${DOCK_INIT_BASE}/lib/util/log.sh"
source "${DOCK_INIT_BASE}/lib/util/rollbar.sh"

# Consul routines used by the main `init.sh` dock-init script.
# @author Ryan Sandor Richards
# @module consul

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

# Echos a value from consul for the given keypath
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
    "Consul-Template was unable to realize the config template."

  # expose VAULT_TOKEN for consul-template config
    if [ -z ${AWS_ACCESS_KEY+x} ] || [ -z ${AWS_SECRET_KEY+x} ]; then
      local NODE_ENV=$(consul::get node/env)
      local token_path="${DOCK_INIT_BASE}/consul-resources/vault/${NODE_ENV}"
      log::info "$token_path"
      # VAULT_TOKEN=$(cat "${token_path}"/auth-token)
      # export VAULT_TOKEN

      USER_VAULT_TOKEN=$(cat "${user_token_path}"/user-vault-auth-token)
      export USER_VAULT_TOKEN

      local template="$DOCK_INIT_BASE/consul-resources/templates/"
      template+="template-config.hcl.ctmpl"
      template+=":$DOCK_INIT_BASE/consul-resources/template-config.hcl"

      consul-template -once -template="$template"
    else
      log::info "AWS access key and secret already created, skipping template creation"
    fi
  rollbar::clear_trap
}

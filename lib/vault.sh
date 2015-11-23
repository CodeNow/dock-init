#!/bin/bash

# Starts vault on the dock, which is used for gathering sensitive data via
# consul.
# @author Ryan Sandor Richards
# @author Bryan Kendall
# @module vault

source "${DOCK_INIT_BASE}/lib/util/rollbar.sh"
source "${DOCK_INIT_BASE}/lib/util/log.sh"

CONSUL_KV_HOST="$CONSUL_HOSTNAME:$CONSUL_PORT/v1/kv"
NODE_ENV=$(curl --silent "$CONSUL_KV_HOST"/node/env | jq --raw-output ".[0].Value" | base64 --decode)
VAULT_CONFIG="$DOCK_INIT_BASE/consul-resources/vault/vault.hcl"

# configure vault
vault::configure() {
  log::trace "Configuring Vault ($VAULT_CONFIG)"
  rollbar::fatal_trap \
    "Vault Start: Failed to Render Vault Config" \
    "Consul-Template was unable to realize the template for Vault."
  local template=''
  template+="$DOCK_INIT_BASE/consul-resources/templates/vault.hcl.ctmpl"
  template+=":$VAULT_CONFIG"
  consul-template -once -template="$template"
  rollbar::clear_trap
}

# Start the vault server
vault::start_server() {
  log::trace "Starting Vault Server"
  rollbar::fatal_trap \
    "Vault Start: Failed to Start" \
    "Vault was unable to start."
  vault server -log-level=warn -config="$VAULT_CONFIG" &
  sleep 5
  local vault_pid=$!
  echo "$vault_pid" > /tmp/vault.pid
  rollbar::clear_trap
  export VAULT_ADDR="http://$LOCAL_IP4_ADDRESS:8200"
}

# Backoff routine to wait for vault to become available
vault::connect_backoff() {
  local attempt=${1}
  local data='{"vault_addr":"'"${VAULT_ADDR}"'","attempt":'"${attempt}"'}'
  log::info "Trying to reach Vault at $VAULT_ADDR $attempt"
  rollbar::warning_trap \
    "Vault Start: Cannot Reach Vault Server" \
    "Attempting to reach local Vault and failing." \
    "$data"
  curl -s "$VAULT_ADDR/v1/auth/seal-status"
  rollbar::clear_trap
}

# Waits for vault to become available via a backoff
vault::connect() {
  log::trace "Connecting to vault"
  backoff vault::connect_backoff
}

# Unseals, unlocks, and checks vault status
vault::unlock() {
  log::trace "Authorizing Vault"
  local token_path="$DOCK_INIT_BASE/consul-resources/vault/$NODE_ENV"
  VAULT_TOKEN=$(cat "${token_path}"/auth-token)
  export VAULT_TOKEN

  local data='{"vault_addr":"'"${VAULT_ADDR}"'"}'
  rollbar::fatal_trap \
    "Vault Start: Failed Unseal" \
    "Vault was unable to be unsealed." \
    "$data"
  log::trace "Unsealing Vault"
  vault unseal "$(cat "${token_path}"/token-01)"
  vault unseal "$(cat "${token_path}"/token-02)"
  vault unseal "$(cat "${token_path}"/token-03)"
  rollbar::clear_trap

  log::trace "Getting Vault Status"
  rollbar::fatal_trap \
    "Vault Start: Failed Status" \
    "Unable to confirm valut status." \
    "$data"
  local status=''
  status=$(vault status)
  rollbar::clear_trap

  log::trace "Vault Status ${status}"
}

# Starts vault
vault::start() {
  log::info "Starting Vault"
  vault::configure
  vault::start_server
  vault::connect
  vault::unlock
}

# Stops vault
vault::stop() {
  log::info "Sealing Vault"
  # reseal vault
  # we have a trap on EXIT in init.sh that will kill it if this fails, so let's
  # just _attempt_ to reseal the vault
  rollbar::warning_trap \
    "Vault Stop: Failed to Seal Vault" \
    "Vault was unable to be sealed."
  vault seal
  rollbar::clear_trap
}

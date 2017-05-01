#!/bin/bash

# This is the primary dock initialization module that is executed via the
# `init.sh` script when a dock is provisioned via shiva. It loads various
# libraries (located in `lib/`)` and composes the exposed methods together to
# fully initialize, start, and register a dock.
#
# @author Ryan Sandor Richards
# @author Bryan Kendall
# @module dock

source "${DOCK_INIT_BASE}/lib/cert.sh"
source "${DOCK_INIT_BASE}/lib/consul.sh"
source "${DOCK_INIT_BASE}/lib/util/backoff.sh"
source "${DOCK_INIT_BASE}/lib/util/log.sh"
source "${DOCK_INIT_BASE}/lib/util/rollbar.sh"

# Sets the value of `$ORG_ID` as the org label in the docker configuration
dock::set_config_org() {
  log::info "Setting organization id in docker configuration"
  echo DOCKER_OPTS=\"\$DOCKER_OPTS --label org="${ORG_ID}"\" >> /etc/default/docker
}

# creates a token for a specific policy
dock::store_vault_token() {
  # export VAULT_ADDR="/* new host */"
  log::info "Storing vault token for private registry key"
  local NODE_ENV=$(consul::get node/env)
  local token_path="${DOCK_INIT_BASE}/consul-resources/vault/${NODE_ENV}"
  VAULT_TOKEN=$(cat "${token_path}"/auth-token)
  vault auth ${VAULT_TOKEN}
  POLICY=$(vault policies | grep "^${ORG_ID}\b")
  if [[ $POLICY ]]; then
    log::info "Policy found for $ORG_ID, generating token"
    vault token-create -policy=${ORG_ID} | awk '/token/ { print $2 }' | awk 'NR==1  {print $1 }' > /opt/runnable/dock-init/private-token
  else
    log::info "Creating new policy and token for $ORG_ID"
    sed "s/{{bpid}}/${ORG_ID}/g" "${DOCK_INIT_BASE}/consul-resources/templates/registry_policy.tmpl" > "${DOCK_INIT_BASE}/consul-resources/templates/registry_policy.hcl"
    vault policy-write ${ORG_ID} "${DOCK_INIT_BASE}/consul-resources/templates/registry_policy.hcl"
    vault token-create -policy=${ORG_ID} | awk '/token/ { print $2 }' | awk 'NR==1  {print $1 }' > /opt/runnable/dock-init/private-token
  fi
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


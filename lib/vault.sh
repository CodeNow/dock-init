#!/bin/bash

# Functions for interacting with vault
# @author Anandkumar Patel

source "${DOCK_INIT_BASE}/lib/util/log.sh"
source "${DOCK_INIT_BASE}/lib/util/rollbar.sh"

# Consul routines used by the main `init.sh` dock-init script.
# @author Ryan Sandor Richards
# @module vault

# Backoff andler for ensuring the dock can connect to vault
# @param $1 attempt The attempt number passed by the backoff routine below
vault::create_s3_policy() {
  rollbar::error_trap \
    "Dock-Init: Cannot create policy template" \
    "Attempting to create s3 policy template."
  log::info "Attempting to create s3 policy template"
  local policy_template="${DOCK_INIT_BASE}/vault-resources/s3.policy"
  local policy_location="${DOCK_INIT_BASE}/vault-resources/s3.policy.json"
  sed /X_ORG_ID/$ORG_ID "${policy_template}" > "${policy_location}"

  backoff vault write aws/roles/deploy policy=@"${policy_location}"
  rollbar::clear_trap
}

# get aws access and secret keys. format:
# Key             Value
# lease_id        aws/creds/deploy/7cb8df71-782f-3de1-79dd-251778e49f58
# lease_duration  3600
# access_key      AKIAIOMYUTSLGJOGLHTQ
# secret_key      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
# security_token  <nil>
vault::get_s3_keys() {
  vault::create_s3_policy

  rollbar::error_trap \
    "Dock-Init: Cannot create policy template" \
    "Attempting to create s3 policy template."
  log::info "Attempting to create s3 policy template"
  vault read aws/creds/s3/$ORG_ID
  rollbar::clear_trap
}

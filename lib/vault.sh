#!/bin/bash

# Functions for interacting with vault
# @author Anandkumar Patel
# @module vault

source "${DOCK_INIT_BASE}/lib/util/log.sh"
source "${DOCK_INIT_BASE}/lib/util/rollbar.sh"

# create s3 policy for this org
vault::create_s3_policy() {
  rollbar::fatal_trap \
    "Dock-Init: Cannot create policy template" \
    "failed to create s3 policy template"

  log::info "Attempting to create s3 policy template"

  local policy_template="${DOCK_INIT_BASE}/vault-resources/s3.policy"
  local policy_location="${DOCK_INIT_BASE}/vault-resources/s3.policy.json"
  sed s/X_ORG_ID/"${ORG_ID}"/g "${policy_template}" > "${policy_location}"

  vault write "aws/roles/s3-${ORG_ID}" policy=@"${policy_location}"

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
  rollbar::fatal_trap \
    "Dock-Init: Cannot create policy template" \
    "failed get s3 creds"

  log::info "Attempting get s3 creds"
  vault read "aws/creds/s3-${ORG_ID}"

  rollbar::clear_trap
}

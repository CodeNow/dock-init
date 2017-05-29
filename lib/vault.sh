#!/bin/bash

# Functions for interacting with vault
# @author Anandkumar Patel
# @module vault

source "${DOCK_INIT_BASE}/lib/util/log.sh"
source "${DOCK_INIT_BASE}/lib/util/rollbar.sh"

if [ -z "${VAULT_PORT+x}" ]; then
  log::fatal "VAULT_PORT is not defined"
  exit 1
else
  export VAULT_PORT
fi

if [ -z "${USER_VAULT_PORT+x}" ]; then
  log::fatal "USER_VAULT_PORT is not defined"
  exit 1
else
  export USER_VAULT_PORT
fi

if [ -z "${VAULT_HOSTNAME+x}" ]; then
  log::fatal "VAULT_HOSTNAME is not defined"
  exit 1
else
  export VAULT_HOSTNAME
fi

if [ -z "${USER_VAULT_HOSTNAME+x}" ]; then
  log::fatal "USER_VAULT_HOSTNAME is not defined"
  exit 1
else
  export USER_VAULT_HOSTNAME
fi

# create s3 policy for this org
# $1 s3 bucket name
vault::create_s3_policy() {
  local bucket="${1}"

  rollbar::fatal_trap \
    "Dock-Init: Cannot create policy template for ${bucket}" \
    "Attempting to create s3 policy template. ${OUTPUT}"

  export VAULT_ADDR="http://${VAULT_HOSTNAME}:${VAULT_PORT}"
  log::info "Attempting to create s3 policy template for bucket ${bucket}"

  local policy_template="${DOCK_INIT_BASE}/vault-resources/s3.policy"
  local policy_location="${DOCK_INIT_BASE}/vault-resources/s3.policy.json"
  sed s/X_ORG_ID/"${ORG_ID}"/g "${policy_template}" | sed s/X_BUCKET/"${bucket}"/g > "${policy_location}"

  OUTPUT="$(vault write aws_1yr/roles/s3-${ORG_ID} policy=@${policy_location})"
  export OUTPUT
  log::trace "vault output: ${OUTPUT}"
  rollbar::clear_trap
}

# set S3_ACCESS_KEY and S3_SECRET_KEY
vault::set_s3_keys() {
  rollbar::fatal_trap \
    "Dock-Init: Cannot create policy template" \
    "Attempting to create s3 policy template. ${OUTPUT}"

  export VAULT_ADDR="http://${VAULT_HOSTNAME}:${VAULT_PORT}"
  log::info "Attempting get s3 creds"
  # Key             Value
  # lease_id        aws/creds/deploy/7cb8df71-782f-3de1-79dd-251778e49f58
  # lease_duration  3600
  # access_key      AKIAIOMYUTSLGJOGLHTQ
  # secret_key      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
  # security_token  <nil>
  OUTPUT="$(vault read aws_1yr/creds/s3-${ORG_ID})"
  export OUTPUT

  S3_ACCESS_KEY="$(echo ${OUTPUT} | grep -o access_key.* | awk '{print $2}')"
  export S3_ACCESS_KEY
  S3_SECRET_KEY="$(echo ${OUTPUT} | grep -o secret_key.* | awk '{print $2}')"
  export S3_SECRET_KEY
  rollbar::clear_trap
}

# creates a token for a the organizations-readonly policy
vault::store_private_registry_token() {
  rollbar::fatal_trap \
    "Dock-Init: Cannot store private registry token" \
    "The user vault token was not generated"

  log::info "Storing vault token for private registry key"
  VAULT_TOKEN_TMP=$VAULT_TOKEN
  unset VAULT_TOKEN

  # this will pull from the vault currently running (our vault)
  export VAULT_ADDR="http://${USER_VAULT_HOSTNAME}:${USER_VAULT_PORT}"
  vault auth ${USER_VAULT_TOKEN}

  log::info "Creating new policy and token for dock-$POPPA_ID"
  sed "s/{{bpid}}/${POPPA_ID}/g" "${DOCK_INIT_BASE}/consul-resources/templates/registry_policy.tmpl" > "${DOCK_INIT_BASE}/consul-resources/templates/registry_policy.hcl"
  vault policy-write dock-${POPPA_ID} "${DOCK_INIT_BASE}/consul-resources/templates/registry_policy.hcl"
  vault token-create -policy=dock-${POPPA_ID} | awk '/token/ { print $2 }' | awk 'NR==1  { print $1 }' > /opt/runnable/dock-init/user-private-registry-token

  VAULT_TOKEN=$VAULT_TOKEN_TMP
  unset VAULT_TOKEN_TMP
  export VAULT_TOKEN
  rollbar::clear_trap
}

#!/bin/bash

# Functions for interacting with vault
# @author Anandkumar Patel
# @module vault

source "${DOCK_INIT_BASE}/lib/util/log.sh"
source "${DOCK_INIT_BASE}/lib/util/rollbar.sh"

# create s3 policy for this org
# $1 s3 bucket name
vault::create_s3_policy() {
  local bucket="${1}"
  log::info "Attempting to create s3 policy template for bucket ${bucket}"

  local policy_template="${DOCK_INIT_BASE}/vault-resources/s3.policy"
  local policy_location="${DOCK_INIT_BASE}/vault-resources/s3.policy.json"
  sed s/X_ORG_ID/"${ORG_ID}"/g "${policy_template}" | sed s/X_BUCKET/"${bucket}"/g > "${policy_location}"

  local output="$(vault write aws/roles/s3-${ORG_ID} policy=@${policy_location})"
  log::trace "vault output: ${output}"
  if [[ "$?" -gt "0" ]]; then
    local data='{"output":'"${output}"'}'
    rollbar::report_error \
      "Dock-Init: Cannot create policy template" \
      "failed to create s3 policy template" \
      "${data}"
    return 1
  fi
}

# set S3_ACCESS_KEY and S3_SECRET_KEY
vault::set_s3_keys() {
  log::info "Attempting get s3 creds"
  # Key             Value
  # lease_id        aws/creds/deploy/7cb8df71-782f-3de1-79dd-251778e49f58
  # lease_duration  3600
  # access_key      AKIAIOMYUTSLGJOGLHTQ
  # secret_key      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
  # security_token  <nil>
  local output="$(vault read aws/creds/s3-${ORG_ID})"
  log::trace "vault output: ${output}"
  if [[ "$?" -gt "0" ]]; then
    local data='{"output":'"${output}"'}'
    rollbar::report_error \
      "Dock-Init: Cannot create policy template" \
      "failed get s3 credentials" \
      "${data}"
    return 1
  fi

  export S3_ACCESS_KEY="$(echo ${output} | grep -o access_key.* | awk '{print $2}')"
  export S3_SECRET_KEY="$(echo ${output} | grep -o secret_key.* | awk '{print $2}')"
  log::trace "access_key: ${S3_ACCESS_KEY} secret_key: ${S3_SECRET_KEY} "
}

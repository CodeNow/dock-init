#!/bin/bash

source "${DOCK_INIT_BASE}/lib/util/log.sh"
source "${DOCK_INIT_BASE}/lib/util/rollbar.sh"
source "${DOCK_INIT_BASE}/lib/util/halter.sh"

# AWS utility methods for the main `init.sh` dock-init script.
# @author Ryan Sandor Richards
# @module aws

# get aws creds for these scripts...
aws::get_aws_creds() {
  # Generate the org-tag fetching script
  rollbar::fatal_trap \
    "Dock-Init: Failed to Render Org Script" \
    "Consule-Template was unable to realize the given template."

  ORG_SCRIPT=$DOCK_INIT_BASE/util/get-aws-creds.sh

  local config="$DOCK_INIT_BASE/consul-resources/template-config.hcl"
  local template="$DOCK_INIT_BASE"
  template+="/consul-resources/templates/get-aws-creds.sh.ctmpl:$ORG_SCRIPT"

  consul-template -config="${config}" -once -template="${template}"

  rollbar::clear_trap
  # give amazon a chance to get the auth
  sleep 5

  source "${DOCK_INIT_BASE}/util/get-aws-creds.sh"
}

# Fetches the org tags from EC2 and sets it to the `ORG_ID` environment variable
aws::get_org_ids() {
  log::info "Setting Github Org ID"

  # Generate the org-tag fetching script
  rollbar::fatal_trap \
    "Dock-Init: Failed to Render Org Script" \
    "Consule-Template was unable to realize the given template."
  if [ -z ${AWS_ACCESS_KEY+x} ] || [ -z ${AWS_SECRET_KEY+x} ]; then
    backoff aws::get_aws_creds
  fi

  EC2_HOME=/usr/local/ec2
  export EC2_HOME

  JAVA_HOME=/usr/lib/jvm/java-7-openjdk-amd64/jre
  export JAVA_HOME

  export INSTANCE_ID=$(ec2-metadata -i | awk '{print $2}')
  # Note: this only works for us-.{4}-\d
  export REGION=$(hostname -d | cut -f1 -d.)

  while [[ "$ORG_ID" == "" ]]
  do
    aws::fetch_org_id
    sleep 2
  done

  while [[ "$POPPA_ID" == "" ]]
  do
    aws::fetch_poppa_id
    sleep 2
  done

  log::info "Got Org ID: $ORG_ID"
  log::info "Got Poppa ID: $POPPA_ID"
}

aws::fetch_org_id() {
  local attempt=${1}
  log::info 'Attempting to get org id'
  data='{"attempt":'"${attempt}"'}'

  rollbar::warning_trap \
    "Dock-Init: Cannot Fetch Org" \
    "Attempting to get the Org Tag from AWS and failing." \
    "$data"

  ORG_ID=$(bash /usr/local/ec2/bin/ec2-describe-tags \
    --aws-access-key="${AWS_ACCESS_KEY}" \
    --aws-secret-key="${AWS_SECRET_KEY}" \
    --filter "resource-type=instance" \
    --filter "resource-id=${INSTANCE_ID}" \
    --filter "key=org" \
    --region "${REGION}" \
    | awk '{print $5}')

  export ORG_ID
}

# Fetches the poppa tags from EC2 and sets it to the `POPPA_ID` environment variable
aws::fetch_poppa_id() {
  log::info "Setting Poppa ID"

  # Generate the org-tag fetching script
  rollbar::warning_trap \
    "Dock-Init: Failed to Render Org Script" \
    "Consule-Template was unable to realize the given template."

  POPPA_ID=$(bash /usr/local/ec2/bin/ec2-describe-tags \
    --aws-access-key="${AWS_ACCESS_KEY}" \
    --aws-secret-key="${AWS_SECRET_KEY}" \
    --filter "resource-type=instance" \
    --filter "resource-id=${INSTANCE_ID}" \
    --filter "key=runnable-org-id" \
    --region "${REGION}" \
    | awk '{print $5}')

  export POPPA_ID
}

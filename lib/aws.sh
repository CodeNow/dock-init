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

  ORG_SCRIPT=$DOCK_INIT_BASE/util/get-org-id.sh

  local config="$DOCK_INIT_BASE/consul-resources/template-config.hcl"
  local template="$DOCK_INIT_BASE"
  template+="/consul-resources/templates/get-org-tag.sh.ctmpl:$ORG_SCRIPT"

  consul-template -config="${config}" -once -template="${template}"

  rollbar::clear_trap
  # give amazon a chance to get the auth
  sleep 5

  source "${DOCK_INIT_BASE}/util/get-org-id.sh"
}

# Fetches the org tags from EC2 and sets it to the `ORG_ID` environment variable
aws::get_org_id() {
  log::info "Setting Github Org ID"

  # Generate the org-tag fetching script
  rollbar::fatal_trap \
    "Dock-Init: Failed to Render Org Script" \
    "Consule-Template was unable to realize the given template."
  if [ -z ${AWS_ACCESS_KEY+x} ] || [ -z ${AWS_SECRET_KEY+x} ]; then
    aws::get_aws_creds
  fi

  log::info "access key $AWS_ACCESS_KEY"
  log::info "secret key $AWS_SECRET_KEY"
  backoff aws::get_org_id_onprem

  if [[ "$ORG_ID" == "" ]]; then
    # this will print an error, so that's good
    rollbar::report_error \
      "Dock-Init: Org ID is Empty After cut" \
      "Evidently the Org ID was bad, and we have an empty ORG_ID."
    # we can not continue, halt
    halter::halt
  fi

  log::info "Got Org ID: $ORG_ID"
}

aws::get_org_id_onprem() {
  local attempt=${1}
  log::info 'Attempting to get org id on prem'
  data='{"attempt":'"${attempt}"'}'

  rollbar::warning_trap \
    "Dock-Init: Cannot Fetch Org" \
    "Attempting to get the Org Tag from AWS and failing." \
    "$data"

  EC2_HOME=/usr/local/ec2
  export EC2_HOME

  JAVA_HOME=/usr/lib/jvm/java-7-openjdk-amd64/jre
  export JAVA_HOME

  local instance_id=$(ec2-metadata -i | awk '{print $2}')

  # Note: this only works for us-.{4}-\d
  local region=$(ec2-metadata --availability-zone | awk '{ where = match($2, /us\-.+\-[1|2]/); print substr($2, where, 9); }')

  ORG_ID=$(bash /usr/local/ec2/bin/ec2-describe-tags \
    --aws-access-key="${AWS_ACCESS_KEY}" \
    --aws-secret-key="${AWS_SECRET_KEY}" \
    --filter "resource-type=instance" \
    --filter "resource-id=${instance_id}" \
    --filter "key=org" \
    --region "${region}" \
    | awk '{print $5}')

  export ORG_ID
}

# Fetches the poppa tags from EC2 and sets it to the `POPPA_ID` environment variable
aws::get_poppa_id() {
  log::info "Setting Poppa ID $AWS_ACCESS_KEY $AWS_SECRET_KEY"

  # Generate the org-tag fetching script
  rollbar::fatal_trap \
    "Dock-Init: Failed to Render Org Script" \
    "Consule-Template was unable to realize the given template."
    EC2_HOME=/usr/local/ec2
    export EC2_HOME

    JAVA_HOME=/usr/lib/jvm/java-7-openjdk-amd64/jre
    export JAVA_HOME

    local instance_id=$(ec2-metadata -i | awk '{print $2}')

    # Note: this only works for us-.{4}-\d
    local region=$(ec2-metadata --availability-zone | awk '{ where = match($2, /us\-.+\-[1|2]/); print substr($2, where, 9); }')

    POPPA_ID=$(bash /usr/local/ec2/bin/ec2-describe-tags \
      --aws-access-key="${AWS_ACCESS_KEY}" \
      --aws-secret-key="${AWS_SECRET_KEY}" \
      --filter "resource-type=instance" \
      --filter "resource-id=${instance_id}" \
      --filter "key=big-poppa" \
      --region "${region}" \
      | awk '{print $5}')

    export POPPA_ID

  log::info "Got POPPA_ID: $POPPA_ID"
}

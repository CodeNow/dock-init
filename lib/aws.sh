#!/bin/bash

# AWS utility methods for the main `init.sh` dock-init script.
# @author Ryan Sandor Richards
# @module aws

# Uses the `ec2-metadata` tool to determine the dock's local ip4 address
aws::get_local_ip() {
  log::info 'Getting IP Address'
  LOCAL_IP4_ADDRESS=$(ec2-metadata --local-ipv4 | awk '{print $2}')
  export LOCAL_IP4_ADDRESS
}

# Backoff routine that attempts to fetch the dock's org id from EC2 tags
aws::fetch_org_id_from_tags() {
  echo `date` "[INFO] Attempting to get org id..."
  data='{"vault_addr":"'"${VAULT_ADDR}"'","attempt":'"${attempt}"'}'
  trap 'report_warn_to_rollbar "Dock-Init: Cannot Fetch Org" "Attempting to get the Org Tag from AWS and failing." "$data"' ERR
  ORG_ID=$(bash $ORG_SCRIPT)
  echo `date` "[TRACE] Script Output: $ORG_ID"
  trap - ERR
  if [[ "$ORG_ID" != "" ]]; then
    return 0
  else
    # report the attempt to rollbar, since we don't want this to always fail
    report_warn_to_rollbar "Dock-Init: Failed to Fetch Org" "Org Script returned an empty string. Retrying."
    return 1
  fi
}

# Fetches the org tags from EC2 and sets it to the `ORG_ID` environment variable
aws::get_org_id() {
  log::info "Setting Github Org ID"

  # Generate the org-tag fetching script
  rollbar::fatal_trap \
    "Dock-Init: Failed to Render Org Script" \
    "Consule-Template was unable to realize the given template."

  ORG_SCRIPT=$DOCK_INIT_BASE/util/get-org-id.sh

  local config="$DOCK_INIT_BASE/consul-resources/template-config.hcl"
  local template="$DOCK_INIT_BASE"
  template += "/consul-resources/templates/get-org-tag.sh.ctmpl:$ORG_SCRIPT"

  consul-template -config="${config}" -once -template="${template}"

  rollbar::clear_trap

  # give amazon a chance to get the auth
  sleep 5

  # Attempt to fetch the org id from the tags via the fetch script
  backoff aws::fetch_org_id_from_tags

  # Parse the org id (assume first value in host_tags comma separated list is
  # org ID)
  ORG_ID=$(echo "$ORG_ID" | cut -d, -f 1)
  export ORG_ID

  if [[ "$ORG_ID" == "" ]]
  then
    # this will print an error, so that's good
    rollbar::report_error \
      "Dock-Init: Org ID is Empty After cut" \
      "Evidently the Org ID was bad, and we have an empty ORG_ID."
    # we've failed, so just exit
    exit 1
  fi

  # Got it! Let's log it an gtfo
  log::info "Got Org ID: $ORG_ID"
}
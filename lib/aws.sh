#!/bin/bash

source "${DOCK_INIT_BASE}/lib/util/log.sh"
source "${DOCK_INIT_BASE}/lib/util/rollbar.sh"
source "${DOCK_INIT_BASE}/lib/util/halter.sh"

# AWS utility methods for the main `init.sh` dock-init script.
# @author Ryan Sandor Richards
# @module aws

# Backoff routine that attempts to fetch the dock's org id from EC2 tags
aws::fetch_org_id_from_tags() {
  local attempt=${1}

  log::info 'Attempting to get org id...'
  data='{"attempt":'"${attempt}"'}'

  rollbar::warning_trap \
    "Dock-Init: Cannot Fetch Org" \
    "Attempting to get the Org Tag from AWS and failing." \
    "$data"
  ORG_ID=$(bash "$ORG_SCRIPT")
  log::trace "Script Output: $ORG_ID"
  rollbar::clear_trap

  if [[ "$ORG_ID" != "" ]]; then
    # Assume first value in host_tags comma separated list is org ID...
    ORG_ID=$(echo "$ORG_ID" | cut -d, -f 1)
    export ORG_ID
    return 0
  else
    # report the attempt to rollbar, since we don't want this to always fail
    rollbar::report_warning \
      "Dock-Init: Failed to Fetch Org" \
      "Org Script returned an empty string. Retrying."
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
  template+="/consul-resources/templates/get-org-tag.sh.ctmpl:$ORG_SCRIPT"

  consul-template -config="${config}" -once -template="${template}"

  rollbar::clear_trap

  # give amazon a chance to get the auth
  sleep 5

  # Attempt to fetch the org id from the tags via the fetch script
  backoff aws::fetch_org_id_from_tags

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

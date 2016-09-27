#!/bin/bash
source "${DOCK_INIT_BASE}/lib/util/log.sh"

halter::halt() {
  if [[ "${USE_EXIT}" == "true" ]]; then
    log::fatal "exiting"
    exit 1
  else
    log::fatal "halting"
    halt
  fi
}

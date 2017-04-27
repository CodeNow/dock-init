#!/bin/bash

# An "on exit" trap to clean up sensitive keys and files on the dock itself.
# Note that this will have no effect if the `DONT_DELETE_KEYS` environment has
# been set (useful for testing)
cleanup::exit_trap() {
  # Delete the keys unless the `DO_NOT_DELETE` flag is set
  if [[ "${DONT_DELETE_KEYS}" == "" ]]; then
    log::info '[CLEANUP TRAP] Removing Keys'
    rm -f "${CERT_PATH}"/ca-key.pem \
          "${CERT_PATH}"/pass \
          "${DOCK_INIT_BASE}"/consul-resources/template-config.hcl \
          "${DOCK_INIT_BASE}"/consul-resources/vault/**/auth-token \
          "${DOCK_INIT_BASE}"/consul-resources/vault/**/token-* \
          "${DOCK_INIT_BASE}"/key/rollbar.token
  fi
}

# Sets the cleanup trap for the entire script
cleanup::set_exit_trap() {
  log::info "Setting key cleanup trap"
  trap 'cleanup::exit_trap' EXIT
}

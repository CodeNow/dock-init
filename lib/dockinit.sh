#!/bin/bash

# Step-wise utility functions for the main `init.sh` dock-init script. Each step
# for the script has been broken up into a single function in this file to make
# the script itself much easier to test.
# @author Ryan Sandor Richards
# @module dockinit

source ./lib/log.sh
source ./lib/rollbar.sh
source ./lib/vault.sh

# An "on exit" trap to clean up sensitive keys and files on the dock itself.
# Note that this will have no effect if the `DONT_DELETE_KEYS` environment has
# been set (useful for testing)
dockinit::cleanup_exit_trap() {
  # Kill vault and clean up the pid file
  if [ -e /tmp/vault.pid ]; then
    log::info '[CLEANUP TRAP] Killing Vault'
    kill "$(cat /tmp/vault.pid)"
    rm /tmp/vault.pid
  fi

  # Delete the keys unless the `DO_NOT_DELETE` flag is set
  if [[ "${DONT_DELETE_KEYS}" == "" ]]; then
    log::info '[CLEANUP TRAP] Removing Keys'
    rm -f "${CERT_PATH}"/ca-key.pem \
          "${CERT_PATH}"/pass \
          "${DOCK_INIT_BASE}"/consul-resources/vault/**/auth-token \
          "${DOCK_INIT_BASE}"/consul-resources/vault/**/token-* \
          "${DOCK_INIT_BASE}"/key/rollbar.token
  fi
}

# Sets the cleanup trap for the entire script
dockinit::set_cleanup_trap() {
  log::info "Setting key cleanup trap"
  trap 'dockinit::cleanup_exit_trap' EXIT
}

# Sets the value of `$ORG_ID` as the org label in the docker configuration
dockinit::set_config_org() {
  log::info "Setting organization id in docker configuration"
  echo DOCKER_OPTS=\"\$DOCKER_OPTS --label org="${ORG_ID}"\" >> /etc/default/docker
}

# Generates upstart scripts for the dock
dockinit::generate_upstart_scripts() {
  log::info "Generating Upstart Scripts"
  rollbar::fatal_trap \
    "Dock-Init: Failed to Generate Upstart Script" \
    "Failed to generate the upstart scripts."
  . "$DOCK_INIT_BASE"/generate-upstart-scripts.sh
  rollbar::clear_trap
}

# Backoff method for generating host certs
dockinit::generate_certs_backoff() {
  rollbar::warning_trap \
    "Dock-Init: Generate Host Certificate" \
    "Failed to generate Docker Host Certificate."
  bash "$CERT_SCRIPT"
  rollbar::clear_trap
}

# Generates host certs for the dock
dockinit::generate_certs() {
  log::info "Generating Host Certificate"
  backoff dockinit::generate_certs_backoff
}

# Generates the correct /etc/hosts file for the dock
dockinit::generate_etc_hosts() {
  log::info "Generating /etc/hosts"

  rollbar::fatal_trap \
    "Dock-Init: Failed to Host Registry Entry" \
    "Consule-Template was unable to realize the given template."

  local template=''
  template+="$DOCK_INIT_BASE/consul-resources/templates/hosts-registry.ctmpl"
  template+=":$DOCK_INIT_BASE/hosts-registry.txt"
  consul-template \
    -config="${DOCK_INIT_BASE}"/consul-resources/template-config.hcl \
    -once \
    -template="${template}"

  rollbar::clear_trap
}

# Sets the correct registry.runnable.com host
dockinit::set_registry_host() {
  log::info "Set registry host"
  cat "$DOCK_INIT_BASE"/hosts-registry.txt >> /etc/hosts
}

# Remove docker key file so it generates a unique id
dockinit::remove_docker_key_file() {
  log::info "Removing docker key.json"
  rm -f /etc/docker/key.json
}

# Start dockers (due to manual override now set in /etc/init)
dockinit::start_docker() {
  log::info "Starting Docker"
  rollbar::fatal_trap \
    "Dock-Init: Failed to Start Docker" \
    "Server was unable to start service."
  service docker start
  rollbar::clear_trap

  log::info "Waiting for Docker"
  local attempt=1
  local timeout=1
  while [ ! -e /var/run/docker.sock ]
  do
    log::info "Docker Sock N/A ($attempt)"
    local title="Dock-Init: Cannot Reach Docker"
    local message="Attempting to reach Docker and failing."
    local data="{\"docker_host\":\"/var/run/docker.sock\",\"attempt\":\"${attempt}\"}"
    rollbar::report_warning "${title}" "${message}" "$data"
    sleep $timeout
    attempt=$(( attempt + 1 ))
    timeout=$(( timeout * 2 ))
  done
}

# Backoff method for attempting to upstart the dock
dockinit::attempt_upstart_backoff() {
  local attempt=${1}
  log::info "Upstarting dock (${attempt})"
  local data='{"attempt":'"${attempt}"'}'
  rollbar::warning_trap \
    "Dock-Init: Cannot Upstart Services" \
    "Attempting to upstart the services and failing." \
    "${data}"
  bash "${UPSTART_SCRIPT}"
  rollbar::clear_trap
}

# Attempts to upstart the dock with exponential backoff
dockinit::attempt_upstart() {
  log::info "Starting Upstart Attempts"
  backoff dockinit::attempt_upstart_backoff
}

# Attempts to stop vault after the dock has been intiialized
dockinit::cleanup::stop_vault() {
  log::info "[CLEANUP] Stop Vault"
  rollbar::fatal_trap \
    "Dock-Init: Failed to stop Vault" \
    "Server was unable to stop Vault."
  vault::stop
  rollbar::clear_trap
}

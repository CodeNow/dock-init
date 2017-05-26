#!/bin/bash

# This is the primary dock initialization module that is executed via the
# `init.sh` script when a dock is provisioned via shiva. It loads various
# libraries (located in `lib/`)` and composes the exposed methods together to
# fully initialize, start, and register a dock.
#
# @author Ryan Sandor Richards
# @author Bryan Kendall
# @module dock

source "${DOCK_INIT_BASE}/lib/cert.sh"
source "${DOCK_INIT_BASE}/lib/util/backoff.sh"
source "${DOCK_INIT_BASE}/lib/util/log.sh"
source "${DOCK_INIT_BASE}/lib/util/rollbar.sh"

# Sets the value of `$ORG_ID` as the org label in the docker configuration
dock::set_config_org() {
  log::info "Setting organization id in docker configuration"
  echo DOCKER_OPTS=\"\$DOCKER_OPTS --label org="${ORG_ID}"\" >> /etc/sysconfig/docker
  echo DOCKER_OPTS=\"\$DOCKER_OPTS -H=unix:///var/run/docker.sock -H=0.0.0.0:4242\" >> /etc/sysconfig/docker
  echo DOCKER_OPTS=\"\$DOCKER_OPTS --tlsverify --tlscacert=/etc/ssl/docker/ca.pem\" >> /etc/sysconfig/docker
  echo DOCKER_OPTS=\"\$DOCKER_OPTS --tlscert=/etc/ssl/docker/cert.pem --tlskey=/etc/ssl/docker/key.pem\" >> /etc/sysconfig/docker

}

# adds org to hostname
dock::set_hostname() {
  log::info "Adding organization id in hostname"
  hostname `hostname`."${ORG_ID}"
}

# Backoff method for generating host certs
dock::generate_certs_backoff() {
  rollbar::warning_trap \
    "Dock-Init: Generate Host Certificate" \
    "Failed to generate Docker Host Certificate."
  cert::generate
  rollbar::clear_trap
}

# Generates host certs for the dock
dock::generate_certs() {
  log::info "Generating Host Certificate"
  backoff dock::generate_certs_backoff
}


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
  echo DOCKER_OPTS=-H=unix:///var/run/docker.sock --tlsverify --tlskey=/etc/ssl/docker/key.pem --tlscert=/etc/ssl/docker/cert.pem --tlscacert=/etc/ssl/docker/ca.pem -H=0.0.0.0:4242 --ip-masq=false --iptables=false --log-driver=json-file --log-level=warn --log-opt=max-file=5 --log-opt=max-size=10m --storage-driver=overlay --label org=$ORG_ID > /etc/sysconfig/docker
  echo DOCKER_NOFILE=1000000 >> /etc/sysconfig/docker

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


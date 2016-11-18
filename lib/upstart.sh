#!/bin/bash

# Functions for generating service upstart scripts from consul templates and
# upstarting services for the dock.
# @author Ryan Sandor Richards
# @author Bryan Kendall

source "${DOCK_INIT_BASE}/lib/consul.sh"
source "${DOCK_INIT_BASE}/lib/util/backoff.sh"
source "${DOCK_INIT_BASE}/lib/util/log.sh"
source "${DOCK_INIT_BASE}/lib/util/rollbar.sh"

# Generates upstart scripts for the dock
upstart::generate_scripts() {
  log::info "Generating Upstart Scripts"
  rollbar::fatal_trap \
    "Dock-Init: Failed to Generate Upstart Script" \
    "Failed to generate the upstart scripts."
  upstart::generate_scripts
  rollbar::clear_trap
}

# Configures the template for a given service
# @param $1 name Name of the service
# @param $2 path Path to the servic
upstart::configure_service() {
  local name="${1}"
  log::trace "Configuring $name"
  rollbar::fatal_trap \
    "Consul-Template: Failed to Render $name Config" \
    "Consule-Template was unable to realize the given template."

  local template_path="$DOCK_INIT_BASE/consul-resources/templates/services"
  template_path+="/$name.conf.ctmpl"
  template_path+=":/etc/init/$name.conf"

  consul-template \
    -config="$DOCK_INIT_BASE/consul-resources/template-config.hcl" \
    -once \
    -template="$template_path"
  echo "manual" > /etc/init/"$name".override

  rollbar::clear_trap
}

# Generates upstart scripts for thoses services that require environment info
# from consul
upstart::generate_scripts() {
  log::info "Configuring Upstart Scripts"
  upstart::configure_service "charon"
  log::trace "Done Generating Upstart Scripts"
}

# Updates a service to the consul version, installs packages, then restarts it.
# @param $1 Name of the service
upstart::upstart_named_service() {
  local name="${1}"
  local attempt="${2}"
  local data='{"attempt":'"${attempt}"'}'
  local version="$(consul::get ${name}/version)"
  local key_path="$DOCK_INIT_BASE/key/id_rsa_runnabledock"

  rollbar::warning_trap \
    "$name: Cannot Upstart Services" \
    "Attempting to upstart the services and failing." \
    "${data}"

  log::info "Updating and restarting $name @ $version" &&
  cd "/opt/runnable/$name" &&
  ssh-agent bash -c "ssh-add $key_path; git fetch origin" &&
  git checkout "$version" &&
  ssh-agent bash -c "ssh-add $key_path; USERPROFILE=/home/ubuntu npm install --production" &&
  service "$name" restart

  rollbar::clear_trap
}

# Starts a service installed on the machine.
# @param $1 Name of the service
# @param $2 Attempt number
upstart::upstart_service() {
  local name="${1}"
  local attempt="${2}"
  local data='{"attempt":'"${attempt}"'}'

  rollbar::warning_trap \
    "$name: Cannot Upstart Service" \
    "Attempting to upstart the service and failing." \
    "${data}"

  log::info "Starting $name"
  service "$name" restart

  rollbar::clear_trap
}

# Start dockers (due to manual override now set in /etc/init)
upstart::start_docker() {
  log::info "Starting Docker"
  rollbar::fatal_trap \
    "Dock-Init: Failed to Start Docker" \
    "Server was unable to start service."
  service docker start
  rollbar::clear_trap

  log::info "Waiting for Docker"
  local attempt=1
  local timeout=.5
  while [ ! -e /var/run/docker.sock ]
  do
    log::info "Docker Sock N/A ($attempt)"
    local title="Dock-Init: Cannot Reach Docker"
    local message="Attempting to reach Docker and failing."
    local data="{\"docker_host\":\"/var/run/docker.sock\",\"attempt\":\"${attempt}\"}"
    rollbar::report_warning "${title}" "${message}" "$data"
    sleep $timeout
    attempt=$(( attempt + 1 ))
  done
}

# Upstarts services that are supposed to be running on the dock.
# @param $1 attempt Attempt number.
upstart::upstart_services_with_backoff_params() {
  local attempt="${1}"
  upstart::upstart_named_service "krain" $attempt
  upstart::upstart_named_service "charon" $attempt
  upstart::upstart_service "datadog-agent" $attempt
}

# Pulls the latest docker image for the runnable image builder
# @param $1 attempt The current attempt for pulling image builder
upstart::pull_image_builder() {
  local attempt="${1}"
  local name="image-builder"
  local version="$(consul::get $name/version)"

  log::info "Pulling image-builder:$version (${attempt})"
  docker pull "registry.runnable.com/runnable/image-builder:$version"

  if [[ "$?" -gt "0" ]]; then
    local data='{"attempt":'"${attempt}"'}'
    rollbar::report_warning \
      "Dock-Init: Cannot Upstart Services" \
      "Attempting to upstart the services and failing." \
      "${data}"
    return 1
  fi
}

# Starts all services needed for the dock
upstart::start() {
  log::info "Upstarting dock"
  upstart::generate_scripts
  upstart::start_docker
  backoff upstart::pull_image_builder
  backoff upstart::upstart_services_with_backoff_params
}

# Stops all dock services
upstart::stop() {
  log::info "Stopping all dock upstart services"
  service krain stop
  service charon stop
  service docker stop
}

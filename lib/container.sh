#!/bin/bash

# Functions for starting container services
# @author Anandkumar Patel

source "${DOCK_INIT_BASE}/lib/consul.sh"
source "${DOCK_INIT_BASE}/lib/util/backoff.sh"
source "${DOCK_INIT_BASE}/lib/util/log.sh"
source "${DOCK_INIT_BASE}/lib/util/rollbar.sh"
source "${DOCK_INIT_BASE}/lib/upstart.sh"
source "${DOCK_INIT_BASE}/lib/vault.sh"

# Starts the docker swarm container
container::_start_swarm_container() {
  local name="swarm"
  local version="1.2.5"

  log::info "Starting swarm:${version} container"
  local docker_logs
  local consul_url="$(consul::get_connection_url)"

  docker_logs=$(docker run \
    --detach=true \
    --restart=always \
    --name "${name}" \
    "${name}:${version}" \
    join --addr="$HOST_IP:4242" \
    "${consul_url}/${name}")

  if [[ "$?" -gt "0" ]]; then
    local data='{"version":'"${version}"', "output":'"${docker_logs}"'}'
    rollbar::report_error \
      "Dock-Init: Cannot Run ${name} Container" \
      "Starting ${name} Container is failing." \
      "${data}"
    return 1
  fi
}

# Starts the docker registry container
container::_start_registry_container() {
  local name="registry"
  local version="2.3.1"
  log::info "Starting ${name}:${version} container"

  local region="$(consul::get s3/region)"
  local bucket="$(consul::get s3/bucket)"
  log::trace "region: ${region} bucket: ${bucket}"

  if [ -z ${S3_ACCESS_KEY+x} ] || [ -z ${S3_SECRET_KEY+x} ]; then
    log::info "Creating S3 credentials"
    vault::create_s3_policy "${bucket}"
    vault::set_s3_keys
  else
    log::info "S3 Credentials already created, setting s3 bucket for registry"
  fi

  local docker_logs
  docker_logs=$(docker run \
    --detach=true \
    --name "${name}" \
    --restart=always \
    --publish=80:5000 \
    -e REGISTRY_HTTP_SECRET="${ORG_ID}" \
    -e REGISTRY_STORAGE=s3 \
    -e REGISTRY_STORAGE_S3_ACCESSKEY="${S3_ACCESS_KEY}" \
    -e REGISTRY_STORAGE_S3_BUCKET="${bucket}"\
    -e REGISTRY_STORAGE_S3_REGION="${region}" \
    -e REGISTRY_STORAGE_S3_ROOTDIRECTORY="/${ORG_ID}" \
    -e REGISTRY_STORAGE_S3_SECRETKEY="${S3_SECRET_KEY}" \
    "${name}:${version}")


  if [[ "$?" -gt "0" ]]; then
    local data='{"version":'"${version}"', "output":'"${docker_logs}"'}'
    rollbar::report_error \
      "Dock-Init: Cannot Run ${name} Container" \
      "Starting ${name} Container is failing." \
      "${data}"
    return 1
  fi
}

# Starts all container services needed for the dock
container::start() {
  log::info "Starting container services"
  upstart::restart_docker
  backoff container::_start_registry_container

  # swarm should be started last so we know everything is up
  backoff container::_start_swarm_container
}

# Stops all dock container services
container::stop() {
  log::info "Stopping all dock container services"
  docker ps | awk '/swarm/ { print $1 }' | xargs docker kill
  docker ps | awk '/registry/ { print $1 }' | xargs docker kill
}

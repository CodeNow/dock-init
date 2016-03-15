#!/bin/bash

# Functions for starting container services
# @author Anandkumar Patel

source "${DOCK_INIT_BASE}/lib/consul.sh"
source "${DOCK_INIT_BASE}/lib/util/backoff.sh"
source "${DOCK_INIT_BASE}/lib/util/log.sh"
source "${DOCK_INIT_BASE}/lib/util/rollbar.sh"

# Starts the docker swarm container
container::_start_swarm_container() {
  local name="swarm"
  local version="$(consul::service_version $name)"

  docker_logs=`docker run \
    -d --restart=always --name "${image_name}" \
    "${name}:${version}" \
    join --addr="$HOST_IP:4242" \
    "consul://${CONSUL_HOSTNAME}:${CONSUL_PORT}/${name}"`

  if [[ "$?" -gt "0" ]]; then
    local data='{"version":'"${version}"', "output":'"${docker_logs}"'}'
    rollbar::report_error \
      "Dock-Init: Cannot Run ${image_name} Container" \
      "Starting ${image_name} Container is failing." \
      "${data}"
    return 1
  fi
}

# Starts the docker registry container
container::_start_registry_container() {
  local name="registry"
  local version="$(consul::service_version $name)"
  local aws_keys="$(vault::get_s3_keys)"
  local awsaccesskey="$(echo ${aws_keys} | awk '/access_key/ { print $2 }')"
  local awssecretkey="$(echo ${aws_keys} | awk '/secret_key/ { print $2 }')"
  local region="$(consul::s3_info $region)"
  local bucket_name="${ORG_ID}"

  docker_logs=`docker run \
    -d --restart=always --name "${image_name}" \
    -p 5000:5000 \
    -e REGISTRY_STORAGE_STORAGE_S3_ACCESSKEY="${awsaccesskey}" \
    -e REGISTRY_STORAGE_STORAGE_S3_SECRETKEY="${awssecretkey}" \
    -e REGISTRY_STORAGE_STORAGE_S3_REGION="${region}" \
    -e REGISTRY_STORAGE_STORAGE_S3_BUCKET="${bucket_name} "\
    "${name}:${version}"`


  if [[ "$?" -gt "0" ]]; then
    local data='{"version":'"${version}"', "output":'"${docker_logs}"'}'
    rollbar::report_error \
      "Dock-Init: Cannot Run ${image_name} Container" \
      "Starting ${image_name} Container is failing." \
      "${data}"
    return 1
  fi
}

# Starts all container services needed for the dock
container::start() {
  log::info "Starting container services"
  backoff container::_start_swarm_container
  backoff container::_start_registry_container
}

# Stops all dock container services
container::stop() {
  log::info "Stopping all dock container services"
  docker ps | awk '/swarm/ { print $1 }' | xargs docker kill
  docker ps | awk '/registry/ { print $1 }' | xargs docker kill
}

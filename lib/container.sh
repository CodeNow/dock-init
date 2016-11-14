#!/bin/bash

# Functions for starting container services
# @author Anandkumar Patel

source "${DOCK_INIT_BASE}/lib/consul.sh"
source "${DOCK_INIT_BASE}/lib/util/backoff.sh"
source "${DOCK_INIT_BASE}/lib/util/log.sh"
source "${DOCK_INIT_BASE}/lib/util/rollbar.sh"
source "${DOCK_INIT_BASE}/lib/vault.sh"

# Starts the docker swarm container
container::_start_swarm_container() {
  local name="swarm"
  local version="$(consul::get ${name}/version)"

  log::info "Starting swarm:${version} container"
  local docker_logs
  docker_logs=$(docker run \
    -d --restart=always --name "${name}" \
    "${name}:${version}" \
    join --addr="$HOST_IP:4242" \
    "consul://${CONSUL_HOSTNAME}:${CONSUL_PORT}/${name}")

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
  local version="$(consul::get ${name}/version)"
  log::info "Starting registry:${version} container"

  local region="$(consul::get s3/region)"
  local bucket="$(consul::get s3/bucket)"
  log::trace "region: ${region} bucket: ${bucket}"

  vault::create_s3_policy "${bucket}"
  vault::set_s3_keys
  local docker_logs
  docker_logs=$(docker run \
    -d --restart=always --name "${name}" \
    -p 80:5000 \
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

container::_start_cadvisor_container() {
  local name="google/cadvisor"
  local version="$(consul::get ${name}/version)"

  log::info "Starting ${name}:${version} container"
  local docker_logs
  docker_logs=$(docker run \
    --name=cadvisor \
    --detach=true \
    --restart=always \
    --volume=/:/rootfs:ro \
    --volume=/var/run:/var/run:rw \
    --volume=/sys:/sys:ro \
    --volume=/var/lib/docker/:/var/lib/docker:ro \
    --publish=29007:8080 \
    --memory=100mb \
    --memory-reservation=50mb \
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

container::_start_node_exporter_container() {
  local name="prom/node-exporter"
  local version="$(consul::get ${name}/version)"

  log::info "Starting ${name}:${version} container"
  local docker_logs
  docker_logs=$(docker run \
    --name=node-exporter \
    --detach=true \
    --restart=always \
    --net=host \
    --memory=100mb \
    --memory-reservation=50mb \
    "${name}:${version}" \
    --collectors.enabled=conntrack,diskstats,filefd,filesystem,loadavg,meminfo,netdev,netstat,stat,time \
    --web.listen-address=:29006)

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
  service docker start
  sleep 10
  backoff container::_start_registry_container
  backoff container::_start_cadvisor_container
  backoff container::_start_node_exporter_container

  # swarm should be started last so we know everything is up
  backoff container::_start_swarm_container
  docker ps | awk '/swarm/ { print $1 }' | xargs docker restart
}

# Stops all dock container services
container::stop() {
  log::info "Stopping all dock container services"
  docker ps | awk '/swarm/ { print $1 }' | xargs docker kill
  docker ps | awk '/registry/ { print $1 }' | xargs docker kill
  docker ps | awk '/cadvisor/ { print $1 }' | xargs docker kill
}

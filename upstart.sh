#!/bin/bash
set -e

# upstart.sh
# Ryan Sandor Richards
#
# This script updates and restarts all of the services on the dock to preferred
# deploy tags.
#
# NOTE: This script will fast fail with a error status code if ANY of the
#       commands required fails.
#
# WARNING: This should not be run on its own, but only by `init.sh`

# Info level logging
# @param $1 Message to log.
function info() {
  echo "" && echo `date` "[INFO] $1"
}

# Error level logging
# @param $1 Message to log.
function error() {
  echo "" && echo `date` "[ERROR] $1"
  # TODO Report error to rollbar
}

# Paths used by the script
RUNNABLE_PATH=/opt/runnable

CHARON_PATH=$RUNNABLE_PATH/charon
DOCK_INIT_PATH=$RUNNABLE_PATH/dock-init
DOCKER_LISTENER_PATH=$RUNNABLE_PATH/docker-listener
FILIBUSTER_PATH=$RUNNABLE_PATH/filibuster
KRAIN_PATH=$RUNNABLE_PATH/krain
SAURON_PATH=$RUNNABLE_PATH/sauron

KEY_PATH=$DOCK_INIT_PATH/key/id_rsa_runnabledock

# Updates and restarts a service
# @param $1 Name of the service
# @param $2 Path to the service
# @param $3 Version to select before deploy
upstart() {
  info "Updating and restarting $1 ($3)" &&
  cd $2 &&
  ssh-agent bash -c "ssh-add $KEY_PATH; git fetch --all >> $DOCK_INIT_LOG_PATH" &&
  git checkout $3 >> $DOCK_INIT_LOG_PATH &&
  ssh-agent bash -c "ssh-add $KEY_PATH; npm install >> $DOCK_INIT_LOG_PATH" &&
  service $1 restart >> $DOCK_INIT_LOG_PATH
}

CONSUL_KV_HOST="$CONSUL_HOSTNAME:8500/v1/kv"

# Pull image builder
IMAGE_BUILDER_VERSION=$(curl --silent $CONSUL_KV_HOST/image-builder/version | jq --raw-output ".[0].Value" | base64 --decode)
info "Pulling image-builder:$IMAGE_BUILDER_VERSION"
docker pull registry.runnable.com/runnable/image-builder:$IMAGE_BUILDER_VERSION >> $DOCK_INIT_LOG_PATH

# Update and start services
FILIBUSTER_VERSION=$(curl --silent $CONSUL_KV_HOST/filibuster/version | jq --raw-output ".[0].Value" | base64 --decode)
upstart filibuster $FILIBUSTER_PATH $FILIBUSTER_VERSION
KRAIN_VERSION=$(curl --silent $CONSUL_KV_HOST/krain/version | jq --raw-output ".[0].Value" | base64 --decode)
upstart krain $KRAIN_PATH $KRAIN_VERSION
SAURON_VERSION=$(curl --silent $CONSUL_KV_HOST/sauron/version | jq --raw-output ".[0].Value" | base64 --decode)
upstart sauron $SAURON_PATH $SAURON_VERSION
CHARON_VERSION=$(curl --silent $CONSUL_KV_HOST/charon/version | jq --raw-output ".[0].Value" | base64 --decode)
upstart charon $CHARON_PATH $CHARON_VERSION
DOCKER_LISTENER_VERSION=$(curl --silent $CONSUL_KV_HOST/docker-listener/version | jq --raw-output ".[0].Value" | base64 --decode)
upstart docker-listener $DOCKER_LISTENER_PATH $DOCKER_LISTENER_VERSION

# Start swarm deamon to register this dock
info "Running swarm container"
consul-template \
  -config=$DOCK_INIT_BASE/consul-resources/template-config.hcl \
  -once \
  -template=$DOCK_INIT_BASE/consul-resources/templates/swarm-url.ctmpl:$DOCK_INIT_BASE/swarm-token.txt
docker run -d --restart=always swarm join --addr=`hostname -I | cut -d' ' -f 1`:4242 $(cat $DOCK_INIT_BASE/swarm-token.txt)

info "Done Upstart"

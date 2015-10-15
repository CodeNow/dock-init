#!/bin/bash

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

source /opt/runnable/env

# If any command fails, fail with the same code
set -e

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
DOCK_INIT_PATH=$RUNNABLE_PATH/dock-init
DOCK_INIT_LOG_PATH=/var/log/dock-init.log
FILIBUSTER_PATH=$RUNNABLE_PATH/filibuster
KRAIN_PATH=$RUNNABLE_PATH/krain
SAURON_PATH=$RUNNABLE_PATH/sauron
DOCKER_LISTENER_PATH=$RUNNABLE_PATH/docker-listener
CHARON_PATH=$RUNNABLE_PATH/charon
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

# Pull image builder
info "Pulling image-builder:$IMAGE_BUILDER_VERSION"
docker pull registry.runnable.com/runnable/image-builder:$IMAGE_BUILDER_VERSION >> $DOCK_INIT_LOG_PATH

# Update and start services
upstart filibuster $FILIBUSTER_PATH $FILIBUSTER_VERSION
upstart krain $KRAIN_PATH $KRAIN_VERSION
upstart sauron $SAURON_PATH $SAURON_VERSION
upstart charon $CHARON_PATH $CHARON_VERSION
upstart docker-listener $DOCKER_LISTENER_PATH $DOCKER_LISTENER_VERSION

# Start swarm deamon to register this dock
docker run -d --restart=always swarm join --addr=`hostname -I | cut -d' ' -f 1`:$DOCKER_PORT token://$SWARM_TOKEN

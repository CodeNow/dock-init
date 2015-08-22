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

FILIBUSTER_PATH=$RUNNABLE_PATH/filibuster
KRAIN_PATH=$RUNNABLE_PATH/krain
SAURON_PATH=$RUNNABLE_PATH/sauron
DOCKER_LISTENER_PATH=$RUNNABLE_PATH/docker-listener

FILIBUSTER_KEY=$DOCK_INIT_PATH/key/id_rsa_filibuster
KRAIN_KEY=$DOCK_INIT_PATH/key/id_rsa_krain
SAURON_KEY=$DOCK_INIT_PATH/key/id_rsa_sauron
DOCKER_LISTENER_KEY=$DOCK_INIT_PATH/key/id_rsa_docker_listener
HERMES_PRIVATE_KEY=$DOCK_INIT_PATH/key/id_rsa_hermes_private

UPSTART_CONF_PATH=/etc/init
DOCKER_LISTENER_UPSTART_CONF=$DOCK_INIT_PATH/docker-listener.conf

# Updates and restarts a service
# @param $1 Name of the service
# @param $2 Path to the service
# @param $3 Path to the service's deploy key
# @param $4 Version to select before deploy
upstart() {
  info "Updating and restarting $1 ($4)" &&
  cd $2 &&
  ssh-agent bash -c "ssh-add $3; git fetch --all" &&
  git checkout $4 &&
  ssh-agent bash -c "ssh-add $HERMES_PRIVATE_KEY; npm install" &&
  service $1 restart
}

# Pull image builder
info "Pulling image-builder:$IMAGE_BUILDER_VERSION"
docker pull registry.runnable.com/runnable/image-builder:$IMAGE_BUILDER_VERSION

# Place the correct upstart script for docker-listener
info "Placing upstart script for docker-listener"
cp $DOCKER_LISTENER_UPSTART_CONF $UPSTART_CONF_PATH

# Update and start services
upstart filibuster $FILIBUSTER_PATH $FILIBUSTER_KEY $FILIBUSTER_VERSION
upstart krain $KRAIN_PATH $KRAIN_KEY $KRAIN_VERSION
upstart sauron $SAURON_PATH $SAURON_KEY $SAURON_VERSION
upstart docker-listener $DOCKER_LISTENER_PATH $DOCKER_LISTENER_KEY $DOCKER_LISTENER_VERSION

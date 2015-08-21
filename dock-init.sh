#!/bin/bash

# dock-init.sh
# By Ryan Sandor Richards
#
# This script updates and restarts all of the services on the dock to preferred
# deploy tags. It is run on start when a dock ami is deployed on EC2 via shiva
#
# NOTE: This script will fast fail with a error status code if ANY of the
#       commands required fails.

# If any command fails, fail with the same code
set -e

# Paths to repositories and keys
FILIBUSTER_PATH=/opt/runnable/filibuster
FILIBUSTER_KEY=/opt/runnable/key/id_rsa_filibuster
KRAIN_PATH=/opt/runnable/krain
KRAIN_KEY=/opt/runnable/key/id_rsa_krain
SAURON_PATH=/opt/runnable/sauron
SAURON_KEY=/opt/runnable/key/id_rsa_sauron
DOCKER_LISTENER_PATH=/opt/runnable/docker-listener
DOCKER_LISTENER_KEY=/opt/runnable/key/id_rsa_docker_listener
HERMES_PRIVATE_KEY=/opt/runnable/key/id_rsa_hermes_private

# Logging utility for the script
# @param $1 Message to log.
log() {
  echo "" && echo "[INFO] $1"
}

# Updates and restarts a service
# @param $1 Name of the service
# @param $2 Path to the service
# @param $3 Path to the service's deploy key
# @param $4 Version to select before deploy
upstart() {
  log "Updating and restarting $1 ($4)" &&
  cd $2 &&
  ssh-agent bash -c "ssh-add $3; git fetch --all" &&
  git checkout $4 &&
  ssh-agent bash -c "ssh-add $HERMES_PRIVATE_KEY; npm install" &&
  service $1 restart
}

# Pull image builder
log "Pulling image-builder:$IMAGE_BUILDER_VERSION"
docker pull registry.runnable.com/runnable/image-builder:$IMAGE_BUILDER_VERSION

# Update and start services
upstart filibuster $FILIBUSTER_PATH $FILIBUSTER_KEY $FILIBUSTER_VERSION
upstart krain $KRAIN_PATH $KRAIN_KEY $KRAIN_VERSION
upstart sauron $SAURON_PATH $SAURON_KEY $SAURON_VERSION
upstart docker-listener $DOCKER_LISTENER_PATH $DOCKER_LISTENER_KEY $DOCKER_LISTENER_VERSION


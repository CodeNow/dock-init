#!/bin/bash

sudo FILIBUSTER_VERSION=v0.1.6 \
     KRAIN_VERSION=v0.0.10 \
     SAURON_VERSION=v0.0.16 \
     IMAGE_BUILDER_VERSION=d1.6.2-v3.0.1 \
     DOCKER_LISTENER_VERSION=v0.8.1 \
     bash /opt/runnable/dock-init/init.sh

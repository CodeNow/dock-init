#!/bin/bash

# Helper script for running dock-init by hand during testing
# @author Ryan Sandor Richards

export DOCK_INIT_BASE=/opt/runnable/dock-init
export CONSUL_HOSTNAME=10.20.1.59
export DONT_DELETE_KEYS=true
export LOG_LEVEL=trace

# Stop any already running services from a previous test
source ./lib/upstart.sh
upstart::stop

# Run the dock start script
bash /opt/runnable/dock-init/init.sh

#!/bin/bash

# Helper script for running dock-init by hand during testing
# @author Ryan Sandor Richards

export DOCK_INIT_BASE=/opt/runnable/dock-init
export CONSUL_HOSTNAME=10.4.5.144
export CONSUL_PORT=8500
export DONT_DELETE_KEYS=true
export USE_EXIT=true
export LOG_LEVEL=trace
export FETCH_ORIGIN_ALL=true

# Run the dock start script
bash /opt/runnable/dock-init/init.sh

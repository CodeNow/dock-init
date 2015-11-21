#!/bin/bash

# Entry-point script for dock initialization. Simply includes the `lib/dock.sh`
# library and calls the master initialization function.
# @author Ryan Sandor Richards

export DOCK_INIT_BASE=/opt/runnable/dock-init
export CONSUL_HOSTNAME
export environment=""

source "${DOCK_INIT_BASE}/lib/dock.sh"

dock::init

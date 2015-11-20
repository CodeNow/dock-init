#!/bin/bash

# Helper script for running dock-init by hand during testing
# @author Ryan Sandor Richards

export CONSUL_HOSTNAME=10.20.1.59
export DONT_DELETE_KEYS=true
export LOG_LEVEL=trace

source ./lib/dock.sh
dock::stop
bash /opt/runnable/dock-init/init.sh

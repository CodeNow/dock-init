#!/bin/bash
# new bash first init script

export DOCK_INIT_BASE=/opt/runnable/dock-init
source "${DOCK_INIT_BASE}/util/run.sh"
source "${DOCK_INIT_BASE}/lib/util/rollbar.sh"
source "${DOCK_INIT_BASE}/lib/consul.sh"
source "${DOCK_INIT_BASE}/lib/dock.sh"
source "${DOCK_INIT_BASE}/lib/upstart.sh"

# Setup the exit trap and rollbar
dock::cleanup::set_exit_trap
rollbar::init
consul::connect
consul::get_environment
consul::configure_consul_template

upstart::start

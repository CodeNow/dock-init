#!/bin/bash

# init.sh
# Ryan Sandor Richards
#
# This is the primary dock initialization script that is executed when a dock
# is provisioned via shiva. It calls the `upstart.sh` script and attempts to
# upstart services. If the upstart fails, it will retry (indefinitely with an
# exponential backoff.

source lib/log.sh
error=$BASH_FUNC_error
log=$BASH_FUNC_log

UPSTART_SCRIPT=/opt/runnable/dock-init/upstart.sh
attempt=1
timeout=1

while true
do
  log "Dock initialization attempt $attempt"
  bash $UPSTART_SCRIPT
  if [[ $? == 0 ]]
  then
    log "Dock successfully initialized after $attempt tries."
    break
  fi

  error "Dock failed to initialize."

  sleep $timeout
  attempt=$(( attempt + 1 ))
  timeout=$(( timeout * 2 ))
done

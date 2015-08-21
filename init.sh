#!/bin/bash

# init.sh
# Ryan Sandor Richards
#
# This is the primary dock initialization script that is executed when a dock
# is provisioned via shiva. It calls the `upstart.sh` script and attempts to
# upstart services. If the upstart fails, it will retry (indefinitely with an
# exponential backoff.

UPSTART_SCRIPT=/opt/runnable/dock-init/upstart.sh
attempt=1
timeout=1

while true
do
  bash $UPSTART_SCRIPT
  if [[ $? == 0 ]]
  then
    break
  fi
  sleep $timeout
  attempt=$(( attempt + 1 ))
  timeout=$(( timeout * 2 ))
done

#!/bin/bash

# init.sh
# Ryan Sandor Richards
#
# This is the primary dock initialization script that is executed when a dock
# is provisioned via shiva. It calls the `upstart.sh` script and attempts to
# upstart services. If the upstart fails, it will retry (indefinitely with an
# exponential backoff.

DOCK_INIT_LOG_PATH=/var/log/dock-init.log
CERT_SCRIPT=/opt/runnable/dock-init/cert.sh
UPSTART_SCRIPT=/opt/runnable/dock-init/upstart.sh

source /opt/runnable/env
echo `date` "[INFO] environment:" `env` >> $DOCK_INIT_LOG_PATH

# Create cert (with exp backoff)
echo `date` "[INFO] Generating Host Certificate"
attempt=1
timeout=1
while true
do
  if [[ $DOCK_INIT_LOG_STDOUT == 1 ]]
  then
    bash $CERT_SCRIPT
  else
    bash $CERT_SCRIPT >> $DOCK_INIT_LOG_PATH
  fi

  if [[ $? == 0 ]]
  then
    break
  fi
  sleep $timeout
  attempt=$(( attempt + 1 ))
  timeout=$(( timeout * 2 ))
done

# Restart docker
service docker restart

# Upstart dock (with exp backoff)
attempt=1
timeout=1
while true
do
  if [[ $DOCK_INIT_LOG_STDOUT == 1 ]]
  then
    bash $UPSTART_SCRIPT
  else
    bash $UPSTART_SCRIPT >> $DOCK_INIT_LOG_PATH
  fi

  if [[ $? == 0 ]]
  then
    break
  fi
  sleep $timeout
  attempt=$(( attempt + 1 ))
  timeout=$(( timeout * 2 ))
done

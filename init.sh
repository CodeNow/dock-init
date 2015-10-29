#!/bin/bash

# init.sh
# Ryan Sandor Richards
#
# This is the primary dock initialization script that is executed when a dock
# is provisioned via shiva. It calls the `upstart.sh` script and attempts to
# upstart services. If the upstart fails, it will retry (indefinitely with an
# exponential backoff.

DOCK_INIT_BASE=/opt/runnable/dock-init
export DOCK_INIT_BASE

DOCK_INIT_LOG_PATH=/var/log/dock-init.log
export DOCK_INIT_LOG_PATH

export CONSUL_HOSTNAME

CERT_SCRIPT=$DOCK_INIT_BASE/cert.sh
UPSTART_SCRIPT=$DOCK_INIT_BASE/upstart.sh

# FIXME(bryan): do we need this any longer?
# source /opt/runnable/env
echo `date` "[INFO] environment:" `env` >> $DOCK_INIT_LOG_PATH

echo `date` "[INFO] Starting Consul Reachability Attempts" >> $DOCK_INIT_LOG_PATH
attempt=1
timeout=1
while true
do
  echo `date` "[INFO] Trying to reach consul at $CONSUL_HOSTNAME:8500 $attempt" >> $DOCK_INIT_LOG_PATH
  if [[ $DOCK_INIT_LOG_STDOUT == 1 ]]
  then
    curl http://$CONSUL_HOSTNAME:8500/v1/status/leader
  else
    curl http://$CONSUL_HOSTNAME:8500/v1/status/leader 2>&1 >> $DOCK_INIT_LOG_PATH
  fi

  if [[ $? == 0 ]]
  then
    break
  fi
  sleep $timeout
  attempt=$(( attempt + 1 ))
  timeout=$(( timeout * 2 ))
done

echo `date` "[INFO] Getting IP Address" >> $DOCK_INIT_LOG_PATH
LOCAL_IP4_ADDRESS=$(ec2-metadata --local-ipv4 | awk '{print $2}')
export LOCAL_IP4_ADDRESS

echo `date` "[INFO] configuring consul-template" >> $DOCK_INIT_LOG_PATH
consul-template \
  -once \
  -template="$DOCK_INIT_BASE/consul-resources/templates/template-config.hcl.ctmpl:$DOCK_INIT_BASE/consul-resources/template-config.hcl"
if [[ $? != 0 ]]; then exit 1; fi

echo `date` "[INFO] Start Vault" >> $DOCK_INIT_LOG_PATH
. $DOCK_INIT_BASE/util/start-vault.sh
if [[ $? != 0 ]]; then echo "[FATAL] Cannot Start Vault"; exit 1; fi

# Add tags to docker config file
# assume first value in host_tags comma separated list is org ID
echo `date` "[INFO] Setting Github Org ID" >> $DOCK_INIT_LOG_PATH
ORG_SCRIPT=$DOCK_INIT_BASE/util/get-org-id.sh
consul-template \
  -config=$DOCK_INIT_BASE/consul-resources/template-config.hcl \
  -once \
  -template=$DOCK_INIT_BASE/consul-resources/templates/get-org-tag.sh.ctmpl:$ORG_SCRIPT
if [[ $? != 0 ]]; then exit 1; fi
sleep 5 # give amazon a chance to get the auth
ORG_ID=$(bash $ORG_SCRIPT)
if [[ $? != 0 ]]; then exit 1; fi
# assume first value in host_tags comma separated list is org ID
ORG_ID=$(echo "$ORG_SCRIPT" | cut -d, -f 1)
export ORG_ID
echo DOCKER_OPTS=\"\$DOCKER_OPTS --label org=$ORG_ID\" >> /etc/default/docker

echo `date` "[INFO] Generate Upstart Scripts" >> $DOCK_INIT_LOG_PATH
. $DOCK_INIT_BASE/generate-upstart-scripts.sh
if [[ $? != 0 ]]; then exit 1; fi

# Create cert (with exp backoff)
echo `date` "[INFO] Generating Host Certificate" >> $DOCK_INIT_LOG_PATH
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

echo `date` "[INFO] Generating Line for /etc/hosts" >> $DOCK_INIT_LOG_PATH
consul-template \
  -config=$DOCK_INIT_BASE/consul-resources/template-config.hcl \
  -once \
  -template=$DOCK_INIT_BASE/consul-resources/templates/hosts-registry.ctmpl:$DOCK_INIT_BASE/hosts-registry.txt
if [[ $? != 0 ]]; then exit 1; fi

# Set correct registry.runnable.com host
echo `date` "[INFO] Set registry host: $registry_host" >> $DOCK_INIT_LOG_PATH
cat $DOCK_INIT_BASE/hosts-registry.txt >> /etc/hosts

# Remove docker key file so it generates a unique id
echo `date` "[INFO] Removing docker key.json" >> $DOCK_INIT_LOG_PATH
rm -f /etc/docker/key.json

echo `date` "[INFO] Starting Docker" >> $DOCK_INIT_LOG_PATH
# Start docker (manual override now set in /etc/init)
service docker start
sleep 1
if [[ $? != 0 ]]; then exit 1; fi

echo `date` "[INFO] Waiting for Docker" >> $DOCK_INIT_LOG_PATH
attempt=1
timeout=1
while [ ! -e /var/run/docker.sock]
do
  echo `date` "[INFO] Docker Sock N/A ($attempt)" >> $DOCK_INIT_LOG_PATH
  sleep $timeout
  attempt=$(( attempt + 1 ))
  timeout=$(( timeout * 2 ))
done

echo `date` "[INFO] Starting Upstart Attempts" >> $DOCK_INIT_LOG_PATH
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

echo `date` "[INFO] Stop Vault" >> $DOCK_INIT_LOG_PATH
. $DOCK_INIT_BASE/util/stop-vault.sh
if [[ $? != 0 ]]; then exit 1; fi

echo `date` "[INFO] Init Done!" >> $DOCK_INIT_LOG_PATH

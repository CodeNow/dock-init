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

# NOTE: all these logs are now piped to a file, so we don't need to pipe our
# output anywhere. Anything printed here will be piped to a log file.

# provided by the user script that runs this script
export CONSUL_HOSTNAME

CERT_SCRIPT=$DOCK_INIT_BASE/cert.sh
UPSTART_SCRIPT=$DOCK_INIT_BASE/upstart.sh

echo `date` "[INFO] Getting IP Address"
LOCAL_IP4_ADDRESS=$(ec2-metadata --local-ipv4 | awk '{print $2}')
export LOCAL_IP4_ADDRESS

# ENVIRONMENT is going to be an empty string until we get the node env in consul
environment=""

cleanup_trap ()
{
  if [ -e /tmp/vault.pid ]
  then
    echo `date` "[INFO] [CLEANUP TRAP] Killing Vault"
    kill `cat /tmp/vault.pid`
  fi
  if [[ "$DONT_DELETE_KEYS" == "" ]]
  then
    echo `date` "[INFO] [CLEANUP TRAP] Removing Keys"
    rm -f $CERT_PATH/ca-key.pem
    rm -f $CERT_PATH/pass
    rm -f $DOCK_INIT_BASE/consul-resources/vault/**/auth-token
    rm -f $DOCK_INIT_BASE/consul-resources/vault/**/token-*
    rm -f $DOCK_INIT_BASE/key/rollbar.token
  fi
}

trap 'cleanup_trap' EXIT

# get the logging to rollbar methods
. $DOCK_INIT_BASE/util/rollbar.sh

echo `date` "[INFO] environment:" `env`

echo `date` "[INFO] Starting Consul Reachability Attempts"
attempt=1
timeout=1
while true
do
  echo `date` "[INFO] Trying to reach consul at $CONSUL_HOSTNAME:8500 $attempt"
  trap 'report_warn_to_rollbar "Dock-Init: Cannot Reach Consul Server" "Attempting to reach Consul and failing."' ERR
  curl http://$CONSUL_HOSTNAME:8500/v1/status/leader 2>&1
  if [[ $? == 0 ]]
  then
    trap - ERR
    break
  fi

  sleep $timeout
  attempt=$(( attempt + 1 ))
  timeout=$(( timeout * 2 ))
done

# now that we can reach consul, we can try to get the environment
trap 'report_err_to_rollbar "Dock-Init: Cannot get Environment" "Unable to reach Consul and retrieve Environment."; exit 1' ERR
environment=$(curl http://$CONSUL_HOSTNAME:8500/v1/kv/node/env 2> /dev/null | jq --raw-output ".[0].Value" | base64 --decode)
trap - ERR
export environment

echo `date` "[INFO] configuring consul-template"
trap 'report_err_to_rollbar "Dock-Init: Failed to Render Template Config" "Consul-Template was unable to realize the given template."; exit 1' ERR
consul-template \
  -once \
  -template="$DOCK_INIT_BASE/consul-resources/templates/template-config.hcl.ctmpl:$DOCK_INIT_BASE/consul-resources/template-config.hcl"
trap - ERR

echo `date` "[INFO] Start Vault"
trap 'report_err_to_rollbar "Dock-Init: Failed to run start-vault.sh" "Vault was unable to start."; exit 1' ERR
. $DOCK_INIT_BASE/util/start-vault.sh
trap - ERR

# Add tags to docker config file
# assume first value in host_tags comma separated list is org ID
echo `date` "[INFO] Setting Github Org ID"
trap 'report_err_to_rollbar "Dock-Init: Failed to Render Org Script" "Consule-Template was unable to realize the given template."; exit 1' ERR
ORG_SCRIPT=$DOCK_INIT_BASE/util/get-org-id.sh
consul-template \
  -config=$DOCK_INIT_BASE/consul-resources/template-config.hcl \
  -once \
  -template=$DOCK_INIT_BASE/consul-resources/templates/get-org-tag.sh.ctmpl:$ORG_SCRIPT
trap - ERR
sleep 5 # give amazon a chance to get the auth

attempt=1
timeout=1
while true
do
  echo `date` "[INFO] Attempting to get org id..."
  data='{"vault_addr":"'"${VAULT_ADDR}"'","attempt":'"${attempt}"'}'
  trap 'report_warn_to_rollbar "Dock-Init: Cannot Fetch Org" "Attempting to get the Org Tag from AWS and failing." "$data"' ERR
  ORG_ID=$(bash $ORG_SCRIPT)
  echo `date` "[TRACE] Script Output: $ORG_ID"
  if [[ "$ORG_ID" != "" ]]
  then
    trap - ERR
    break
  else
    # report the attempt to rollbar, since we don't want this to always fail
    report_warn_to_rollbar "Dock-Init: Failed to Fetch Org" "Org Script returned an empty string. Retrying."
  fi
  sleep $timeout
  attempt=$(( attempt + 1 ))
  timeout=$(( timeout * 2 ))
done

export ORG_ID
# assume first value in host_tags comma separated list is org ID
ORG_ID=$(echo "$ORG_ID" | cut -d, -f 1)
export ORG_ID
if [[ "$ORG_ID" == "" ]]
then
  # this will print an error, so that's good
  report_err_to_rollbar "Dock-Init: Org ID is Empty After cut" "Evidently the Org ID was bad, and we have an empty ORG_ID."
  # we've failed, so just exit
  exit 1
fi
echo `date` "[INFO] Got Org ID: $ORG_ID"

echo DOCKER_OPTS=\"\$DOCKER_OPTS --label org=$ORG_ID\" >> /etc/default/docker

echo `date` "[INFO] Generate Upstart Scripts"
trap 'report_err_to_rollbar "Dock-Init: Failed to Generate Upstart Script" "Failed to generate the upstart scripts."; exit 1' ERR
. $DOCK_INIT_BASE/generate-upstart-scripts.sh
trap - ERR

# Create cert (with exp backoff)
echo `date` "[INFO] Generating Host Certificate"
attempt=1
timeout=1
while true
do
  trap 'report_warn_to_rollbar "Dock-Init: Generate Host Certificate" "Failed to generate Docker Host Certificate."' ERR
  bash $CERT_SCRIPT

  if [[ $? == 0 ]]
  then
    trap - ERR
    break
  fi
  sleep $timeout
  attempt=$(( attempt + 1 ))
  timeout=$(( timeout * 2 ))
done

echo `date` "[INFO] Generating Line for /etc/hosts"
trap 'report_err_to_rollbar "Dock-Init: Failed to Host Registry Entry" "Consule-Template was unable to realize the given template."; exit 1' ERR
consul-template \
  -config=$DOCK_INIT_BASE/consul-resources/template-config.hcl \
  -once \
  -template=$DOCK_INIT_BASE/consul-resources/templates/hosts-registry.ctmpl:$DOCK_INIT_BASE/hosts-registry.txt
trap - ERR

# Set correct registry.runnable.com host
echo `date` "[INFO] Set registry host: $registry_host"
cat $DOCK_INIT_BASE/hosts-registry.txt >> /etc/hosts

# Remove docker key file so it generates a unique id
echo `date` "[INFO] Removing docker key.json"
rm -f /etc/docker/key.json

echo `date` "[INFO] Starting Docker"
# Start docker (manual override now set in /etc/init)
trap 'report_err_to_rollbar "Dock-Init: Failed to Start Docker" "Server was unable to start service."; exit 1' ERR
service docker start
trap - ERR

echo `date` "[INFO] Waiting for Docker"
attempt=1
timeout=1
while [ ! -e /var/run/docker.sock ]
do
  echo `date` "[INFO] Docker Sock N/A ($attempt)"
  data='{"docker_host":"/var/run/docker.sock","attempt":'"${attempt}"'}'
  report_warn_to_rollbar "Dock-Init: Cannot Reach Docker" "Attempting to reach Docker and failing." "$data"
  sleep $timeout
  attempt=$(( attempt + 1 ))
  timeout=$(( timeout * 2 ))
done

echo `date` "[INFO] Starting Upstart Attempts"
# Upstart dock (with exp backoff)
attempt=1
timeout=1
while true
do
  data='{"attempt":'"${attempt}"'}'
  trap 'report_warn_to_rollbar "Dock-Init: Cannot Upstart Services" "Attempting to upstart the services and failing." "$data"' ERR
  bash $UPSTART_SCRIPT

  if [[ $? == 0 ]]
  then
    trap - ERR
    break
  fi
  sleep $timeout
  attempt=$(( attempt + 1 ))
  timeout=$(( timeout * 2 ))
done

echo `date` "[INFO] Stop Vault"
trap 'report_err_to_rollbar "Dock-Init: Failed to stop Vault" "Server was unable to stop Vault."; exit 1' ERR
. $DOCK_INIT_BASE/util/stop-vault.sh
trap - ERR

echo `date` "[INFO] Init Done!"

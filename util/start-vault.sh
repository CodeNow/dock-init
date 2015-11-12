#!/bin/bash

echo `date` "[INFO] Starting Vault"

# get the logging to rollbar methods
. $DOCK_INIT_BASE/util/rollbar.sh

CONSUL_KV_HOST="$CONSUL_HOSTNAME:8500/v1/kv"
NODE_ENV=$(curl --silent $CONSUL_KV_HOST/node/env | jq --raw-output ".[0].Value" | base64 --decode)
# NOTE: $NODE_ENV and $environment are going to be the same, but that's cool.

VAULT_CONFIG=$DOCK_INIT_BASE/consul-resources/vault/vault.hcl
echo `date` "[TRACE] Configuring Vault ($VAULT_CONFIG)"
# configure vault
trap 'report_err_to_rollbar "Vault Start: Failed to Render Vault Config" "Consul-Template was unable to realize the template for Vault."; exit 1' ERR
consul-template \
  -once \
  -template=$DOCK_INIT_BASE/consul-resources/templates/vault.hcl.ctmpl:$VAULT_CONFIG
trap - ERR

echo `date` "[TRACE] Starting Vault Server"
# start vault server
trap 'report_err_to_rollbar "Vault Start: Failed to Start" "Vault was unable to start."; exit 1' ERR
vault server -log-level=warn -config=$VAULT_CONFIG &
sleep 5
vault_pid=$!
echo $vault_pid > /tmp/vault.pid
trap - ERR

VAULT_ADDR="http://$LOCAL_IP4_ADDRESS:8200"
export VAULT_ADDR

echo `date` "[TRACE] Waiting for Vault to come up"
attempt=1
timeout=1
while true
do
  echo `date` "[INFO] Trying to reach Vault at $VAULT_ADDR $attempt"
  data='{"vault_addr":"'"${VAULT_ADDR}"'","attempt":'"${attempt}"'}'
  trap 'report_warn_to_rollbar "Vault Start: Cannot Reach Vault Server" "Attempting to reach local Vault and failing." "$data";' ERR
  curl -s $VAULT_ADDR/v1/auth/seal-status

  if [[ $? == 0 ]]
  then
    trap - ERR
    break
  fi
  sleep $timeout
  attempt=$(( attempt + 1 ))
  timeout=$(( timeout * 2 ))
done

echo `date` "[TRACE] Authing Vault"
data='{"vault_addr":"'"${VAULT_ADDR}"'"}'
trap 'report_err_to_rollbar "Vault Start: Failed Unseal" "Vault was unable to be unsealed." "$data"; exit 1' ERR
# vault unseal and unlock
VAULT_TOKEN=$(cat $DOCK_INIT_BASE/consul-resources/vault/$NODE_ENV/auth-token)
export VAULT_TOKEN
echo `date` "[TRACE] Unsealing Vault"
vault unseal `cat $DOCK_INIT_BASE/consul-resources/vault/$NODE_ENV/token-01`
vault unseal `cat $DOCK_INIT_BASE/consul-resources/vault/$NODE_ENV/token-02`
vault unseal `cat $DOCK_INIT_BASE/consul-resources/vault/$NODE_ENV/token-03`
trap - ERR

echo `date` "[TRACE] Vault Status"
# use $data from above
trap 'report_err_to_rollbar "Vault Start: Failed Status" "Unable to confirm valut status." "$data"; exit 1' ERR
vault status
trap - ERR

if [[ "$DONT_DELETE_KEYS" == "" ]]
then
  rm -f $DOCK_INIT_BASE/consul-resources/vault/**/auth-token
  rm -f $DOCK_INIT_BASE/consul-resources/vault/**/token-*
fi

echo `date` "[TRACE] Vault Status `vault status`"

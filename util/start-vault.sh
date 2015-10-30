#!/bin/bash
set -e

echo `date` "[INFO] Starting Vault" >> $DOCK_INIT_LOG_PATH

CONSUL_KV_HOST="$CONSUL_HOSTNAME:8500/v1/kv"
NODE_ENV=$(curl --silent $CONSUL_KV_HOST/node/env | jq --raw-output ".[0].Value" | base64 --decode)

VAULT_CONFIG=$DOCK_INIT_BASE/consul-resources/vault/vault.hcl
echo `date` "[TRACE] Configuring Vault ($VAULT_CONFIG)" >> $DOCK_INIT_LOG_PATH
# configure vault
consul-template \
  -once \
  -template=$DOCK_INIT_BASE/consul-resources/templates/vault.hcl.ctmpl:$VAULT_CONFIG

echo `date` "[TRACE] Starting Vault Server" >> $DOCK_INIT_LOG_PATH
# start vault server
vault server -log-level=warn -config=$VAULT_CONFIG >> $DOCK_INIT_LOG_PATH &
sleep 5
vault_pid=$!
echo $vault_pid > /tmp/vault.pid

echo `date` "[TRACE] Authing Vault" >> $DOCK_INIT_LOG_PATH
# vault unseal and unlock
VAULT_ADDR="http://$LOCAL_IP4_ADDRESS:8200"
export VAULT_ADDR
VAULT_TOKEN=$(cat $DOCK_INIT_BASE/consul-resources/vault/$NODE_ENV/auth-token)
export VAULT_TOKEN
echo `date` "[TRACE] Unsealing Vault" >> $DOCK_INIT_LOG_PATH
vault unseal `cat $DOCK_INIT_BASE/consul-resources/vault/$NODE_ENV/token-01` >> $DOCK_INIT_LOG_PATH
vault unseal `cat $DOCK_INIT_BASE/consul-resources/vault/$NODE_ENV/token-02` >> $DOCK_INIT_LOG_PATH
vault unseal `cat $DOCK_INIT_BASE/consul-resources/vault/$NODE_ENV/token-03` >> $DOCK_INIT_LOG_PATH

echo `date` "[TRACE] Vault Status" >> $DOCK_INIT_LOG_PATH
vault status >> $DOCK_INIT_LOG_PATH

rm -f $DOCK_INIT_BASE/consul-resources/vault/**/auth-token
rm -f $DOCK_INIT_BASE/consul-resources/vault/**/token-*

echo `date` "[TRACE] Vault Status `vault status`" >> $DOCK_INIT_LOG_PATH

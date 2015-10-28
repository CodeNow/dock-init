#!/bin/bash
set -e

echo `date` "[INFO] Starting Vault" >> $DOCK_INIT_LOG_PATH

VAULT_CONFIG=$DOCK_INIT_BASE/consul-resources/vault/vault.hcl
echo `date` "[TRACE] Configuring Vault ($VAULT_CONFIG)" >> $DOCK_INIT_LOG_PATH
# configure vault
consul-template \
  -once \
  -template=$DOCK_INIT_BASE/consul-resources/templates/vault.hcl.ctmpl:$VAULT_CONFIG

echo `date` "[TRACE] Starting Vault Server" >> $DOCK_INIT_LOG_PATH
# start vault server
vault server -log-level=warn -config=$VAULT_CONFIG &
sleep 1
vault_pid=$!
echo $vault_pid > /tmp/vault.pid

echo `date` "[TRACE] Unsealing and Authing Vault" >> $DOCK_INIT_LOG_PATH
# vault unseal and unlock
VAULT_ADDR="http://$LOCAL_IP4_ADDRESS:8200"
export VAULT_ADDR
vault unseal `cat $DOCK_INIT_BASE/consul-resources/vault/token-01`
vault unseal `cat $DOCK_INIT_BASE/consul-resources/vault/token-02`
vault unseal `cat $DOCK_INIT_BASE/consul-resources/vault/token-03`
rm -f $DOCK_INIT_BASE/consul-resources/vault/token-*
VAULT_TOKEN=$(cat $DOCK_INIT_BASE/consul-resources/vault/auth-token)
export VAULT_TOKEN
rm -f $DOCK_INIT_BASE/consul-resources/vault/auth-token

vault status >> $DOCK_INIT_LOG_PATH

echo `date` "[TRACE] Vault Status `vault status`" >> $DOCK_INIT_LOG_PATH

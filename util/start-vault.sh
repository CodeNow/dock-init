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
vault server -log-level=warn -config=$VAULT_CONFIG >> $DOCK_INIT_LOG_PATH &
sleep 5
vault_pid=$!
echo $vault_pid > /tmp/vault.pid

echo `date` "[TRACE] Authing Vault" >> $DOCK_INIT_LOG_PATH
# vault unseal and unlock
VAULT_ADDR="http://$LOCAL_IP4_ADDRESS:8200"
export VAULT_ADDR
VAULT_TOKEN=$(cat $DOCK_INIT_BASE/consul-resources/vault/auth-token)
export VAULT_TOKEN
rm -f $DOCK_INIT_BASE/consul-resources/vault/auth-token
echo `date` "[TRACE] Unsealing Vault" >> $DOCK_INIT_LOG_PATH
vault unseal `cat $DOCK_INIT_BASE/consul-resources/vault/token-01` >> $DOCK_INIT_LOG_PATH
vault unseal `cat $DOCK_INIT_BASE/consul-resources/vault/token-02` >> $DOCK_INIT_LOG_PATH
vault unseal `cat $DOCK_INIT_BASE/consul-resources/vault/token-03` >> $DOCK_INIT_LOG_PATH
rm -f $DOCK_INIT_BASE/consul-resources/vault/token-*

echo `date` "[TRACE] Vault Status" >> $DOCK_INIT_LOG_PATH
vault status >> $DOCK_INIT_LOG_PATH

echo `date` "[TRACE] Vault Status `vault status`" >> $DOCK_INIT_LOG_PATH

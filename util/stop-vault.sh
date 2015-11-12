#!/bin/bash
set -e

echo `date` "[TRACE] Sealing Vault"
# reseal vault
# we have a trap on EXIT in init.sh that will kill it if this fails, so let's
# just _attempt_ to reseal the vault
trap 'report_warn_to_rollbar "Vault Stop: Failed to Seal Vault" "Vault was unable to be sealed.";' ERR
vault seal
trap - ERR

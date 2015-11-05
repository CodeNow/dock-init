#!/bin/bash
set -e

echo `date` "[TRACE] Sealing Vault" >> $DOCK_INIT_LOG_PATH
# reseal vault
vault seal
kill `cat /tmp/vault.pid`
rm /tmp/vault.pid

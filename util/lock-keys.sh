#!/bin/bash

KEYS_PATH=/opt/runnable/dock-init/key
chmod 400 $KEYS_PATH/id_rsa_runnabledock

#
# until or unless we start NOT using root as the git user for docks, which we most certainly do, the keys need to be owned by root.
#

sudo chown root:root $KEYS_PATH/id_rsa_runnabledock

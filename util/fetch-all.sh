#!/bin/bash
ssh-agent bash -c "ssh-add key/id_rsa_runnabledock; git fetch --all"

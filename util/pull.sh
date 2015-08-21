#!/bin/bash
ssh-agent bash -c "ssh-add key/id_rsa_dock_init; git pull origin $1"

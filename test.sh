#!/bin/bash

# Script for setting up the test environment and running the dock-init shpec
# tests. Note: this should be the only way that tests are run as it is
# responsible for exporting specific varibales that, if not set, will stop the
# tests from running.
# @author Ryan Sandor Richards

export LOG_LEVEL=none
export DOCK_INIT_BASE=$(pwd)
source $DOCK_INIT_BASE/test/fixtures/stub.sh

# TODO Flesh out tests and add test/*.sh
shpec test/*/*.sh

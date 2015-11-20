#!/bin/bash

# Script for setting up the test environment and running the dock-init shpec
# tests. Note: this should be the only way that tests are run as it is
# responsible for exporting specific varibales that, if not set, will stop the
# tests from running.
# @author Ryan Sandor Richards

source $DOCK_INIT_BASE/test/fixtures/stub.sh
export DOCK_INIT_BASE=$(pwd)
shpec test/**/*.sh

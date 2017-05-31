#!/bin/bash

# Script for setting up the test environment and running the dock-init shpec
# tests. Note: this should be the only way that tests are run as it is
# responsible for exporting specific varibales that, if not set, will stop the
# tests from running.
#
# Finally you can pass a specific path to the test runner by passing the glob
# path as the first argument to the script, for example:
#
#   $ bash unit.sh test/util/log.sh
#
# will only run the specific `test/util/log.sh` test. Another example:
#
#   $ bash unit.sh test/util/*.sh
#
# will run all tests in the the `test/util` directory.

export LOG_LEVEL=none
export DOCK_INIT_BASE=$(pwd)
export HOST_IP='127.0.0.1'
export USE_EXIT=true
export VAULT_PORT=7777
export VAULT_HOSTNAME=test-vault
export CONSUL_PORT=8888
export CONSUL_HOSTNAME=test-consul
export USER_VAULT_PORT=9999
export USER_VAULT_HOSTNAME=test-user-vault
export DOCKER_CERT_CA_BASE64=test-DOCKER_CERT_CA_BASE64
export DOCKER_CERT_CA_KEY_BASE64=test-DOCKER_CERT_CA_KEY_BASE64
export DOCKER_CERT_PASS=test-DOCKER_CERT_PASS

# See if the user passed a spcific test path
test_path="$1"
if [[ "$test_path" == "" ]]; then
  # TODO Flesh out tests and add test/*.sh
  test_path1="test/*.sh"
  test_path2="test/*/*.sh"
  test_path="$test_path1 $test_path2"
fi

# Run the tests using shpec
shpec "$test_path"

#!/bin/bash

# Custom stubbing methods. The methods provided by shpec do not stub functions
# and commands correctly (specifically they do not pass arguments). Hopefully
# we can contribute back to shpec in the future.

# Stubs a command of the given name and ensures the first 4 arguments are
# passed to the stub upon execution.
# @param $1 name Name of the command to stub
# @param $2 [body] The body of for the stub (optional)
stub::set() {
  local name="${1}"
  local body="${2}"
  if [[ $body == '' ]]; then
    eval "${name}() { return 0; }"
  else
    eval "${name}() { ${body} \$1 \$2 \$3 \$4; }"
  fi
}

# Restores a stubbed command to its original state
# @param $1 name Name of the stubbed command
stub::restore() {
  local name="${1}"
  unset -f "$name"
}

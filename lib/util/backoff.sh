#!/bin/bash

# Routines for handling exponetial back off
# @module util:backoff

# Attempts to run the given function and on failure sleeps then tries again.
# Each failure increases the sleep time by a power of two, and thus we backoff
# our attempts exponentially.
#
# The given function should accept two parameters. The first parameter will be
# the current attempt count, and the secon paramter will be the next sleep
# timeout.
#
# @param $1 action Command to execute under the exponetial backoff
# @param $2 failureFunc Function to run after errored $action
# @param $3 successFunc Function to run after successful $action
backoff() {
  local action=${1}
  local failureFunc=${2}
  local successFunc=${3}
  local attempt=1
  local timeout=1
  while true; do
    $action $attempt $timeout
    if (( $? == 0 )); then
      if [ "$(type -t $successFunc)" = "function" ]; then
        $successFunc $attempt $timeout
      fi
      break
    else
      if [ "$(type -t $failureFunc)" = "function" ]; then
        $failureFunc $attempt $timeout
      fi
    fi
    sleep $timeout
    attempt=$(( attempt + 1 ))
    timeout=$(( timeout * 2 ))
  done
}

#!/bin/bash

# Attempts to run the given function and on failure sleeps then tries again.
# Each failure increases the sleep time by a power of two, and thus we backoff
# our attempts exponentially.
#
# The given function should accept two parameters. The first parameter will be
# the current attempt count, and the secon paramter will be the next sleep
# timeout.
#
# @param $1 action Function to execute under the exponetial backoff
# @param $2 backoff_cond Function that determines whether or not the backoff
#   should continue due to some external constraint (socket is open, etc.). The
#   function should return 0 if the backoff should continue to keep trying and
#   1 if it should stop. By default the backoff will always keep trying.
backoff() {
  local action=${1}
  local backoff_cond=${2}
  local argc=$#
  local attempt=1
  local timeout=1

  while true; do
    # Use the backoff condition (if given) to determine if we should keep
    # attempting the given action function
    if (( argc == 2 )); then
      $backoff_cond
      if (( $? != 0 )); then break; fi
    fi

    # Run the action and see if it succeeds
    $action $attempt $timeout
    if (( $? == 0 ))
    then
      break
    fi
    sleep $timeout
    attempt=$(( attempt + 1 ))
    timeout=$(( timeout * 2 ))
  done
}

#!/bin/bash

# lib/log.sh
# Ryan Sandor Richards
#
# Logging utility functions for dock-init scripts.

# Info level logging
# @param $1 Message to log.
info() { echo "" && echo "[INFO] $1" }

# Error level logging
# @param $1 Message to log.
error() {
  echo "" && echo "[ERROR] $1"
  # TODO Report error to rollbar
}

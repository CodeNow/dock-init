#!/bin/bash

# Logging module for dock-init. Provides easy to use shortcuts for handling
# logging at various levels. Logging can be controlled via the LOG_LEVEL
# environment variable. The log priorities is exactly that of the bunyan logging
# package.
#
# @see https://github.com/trentm/node-bunyan#levels

# Converts a log level string to the appropriate integer
# @param [$1] given_level Optional given level to convert into an integer
log::_get_log_level_int() {
  local given_level=${1}
  local log_level_text

  # Determine the log level text to convert based on params, etc.
  if [ "${given_level}" ]; then
    log_level_text=${given_level}
  elif [ "${LOG_LEVEL}" ]; then
    log_level_text=${LOG_LEVEL}
  else
    log_level_text='info'
  fi
  log_level_text=$(echo "$log_level_text" | tr '[:upper:]' '[:lower:]')

  # Return the appropriate log level number based on the level text
  local log_level_number=30
  if [[ "${log_level_text}" == 'fatal' ]]; then
    log_level_number=60
  elif [[ "${log_level_text}" == 'error' ]]; then
    log_level_number=50
  elif [[ "${log_level_text}" == 'warn' ]]; then
    log_level_number=40
  elif [[ "${log_level_text}" == 'info' ]]; then
    log_level_number=30
  elif [[ "${log_level_text}" == 'debug' ]]; then
    log_level_number=20
  elif [[ "${log_level_text}" == 'trace' ]]; then
    log_level_number=10
  elif [[ "${log_level_text}" == 'none' ]]; then
    log_level_number=0
  fi
  echo $log_level_number
}

# Echos a dated log line with the given level and message to stdout.
# @param $1 level The level of the log.
# @param $2 message The message for the log.
log::message() {
  local level=${1}
  local message=${2}

  # Check to see if the user has enabled the given log level via environment
  local given_log_level=''
  given_log_level=$(log::_get_log_level_int "${level}")
  local global_log_level=''
  global_log_level=$(log::_get_log_level_int)
  if (( global_log_level > given_log_level )); then
    return 0
  fi

  # Log the message
  echo "$(date) [$level] $message"
}

# Echos an 'FATAL' level log message.
# @param $1 message The message to log.
log::fatal() {
  local message=${1}
  log::message 'FATAL' "$message"
}

# Echos an 'ERROR' level log message.
# @param $1 message The message to log.
log::error() {
  local message=${1}
  log::message 'ERROR' "$message"
}

# Echos an 'WARN' level log message.
# @param $1 message The message to log.
log::warn() {
  local message=${1}
  log::message 'WARN' "$message"
}

# Echos an 'INFO' level log message.
# @param $1 message The message to log.
log::info() {
  local message=${1}
  log::message 'INFO' "$message"
}

# Echos an 'DEBUG' level log message.
# @param $1 message The message to log.
log::debug() {
  local message=${1}
  log::message 'DEBUG' "$message"
}

# Echos an 'TRACE' level log message.
# @param $1 message The message to log.
log::trace() {
  local message=${1}
  log::message 'TRACE' "$message"
}

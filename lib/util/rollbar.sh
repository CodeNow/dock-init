#!/bin/bash

source "${DOCK_INIT_BASE}/lib/util/log.sh"
source "${DOCK_INIT_BASE}/lib/util/halter.sh"

# Module for handling reporting to rollbar within dock-init bash scripts. This
# module exposes various report_* and trap_* methods that can be used to easily
# ineteract and send messages to rollbar.
# @module util:rollbar

# Ensures the module has a rollbar token
rollbar::init() {
  if [[ "$ROLLBAR_TOKEN" == "" ]]; then
    export ROLLBAR_TOKEN=$(cat "$DOCK_INIT_BASE/key/rollbar.token")
  fi
}

# Echos a payload based on the provided arguments
# @param $1 level The error level of the report
# @param $2 title Title for the report
# @param $3 message Message to report
# @param $4 data Additional JSON data to report
rollbar::_get_payload() {
  local level="$1"
  local title="$2"
  local message="$3"
  local data="$4"
  local timestamp=$(date +'%s')
  local payload='
  {
    "access_token": "'"${ROLLBAR_TOKEN}"'",
    "data": {
      "environment": "'"${environment}"'",
      "level": "'"${level}"'",
      "title": "'"${title}"'",
      "timestamp": "'"${timestamp}"'",
      "body": {
        "message": {
          "body": "'"${message}"'",
          "data": '"${data}"'
        }
      },
      "server": {
        "host": "'"${HOST_IP}"'"
      }
    }
  }';
  echo "$payload"
}

# Reports a general message to rollbar with the given error level
# @param $1 level The error level of the report
# @param $2 title Title for the report
# @param $3 message Message to report
# @param $4 data Additional JSON data to report
rollbar::report () {
  local level="$1"
  local title="$2"
  local message="$3"
  local data="$4"

  # verify that data is valid JSON
  if [[ "$data" == "" ]]; then
    data='{}'
  fi

  echo "$data" | jq "." > /dev/null 2>&1
  if (( $? != 0 )); then
    log::warn 'Invalid JSON Data was Passed with $title, $message'
    data='{}'
  fi

  # trap a curl error here to print a fatal error.
  trap 'log::fatal "COULD NOT REPORT TO ROLLBAR"; halter::halt' ERR
  local json
  json=$(rollbar::_get_payload "$level" "$title" "$message" "$data")
  curl -s -q -H "Content-Type: application/json" \
    -d "$json" \
    "https://api.rollbar.com/api/1/item/" > /dev/null
  trap - ERR
  log::info "Error Reported to Rollbar ($level)"
}

# Reports errors via rollbar.
# @param $1 Title for the report
# @param $2 Message to report
# @param $3 Additional data to report (format?)
rollbar::report_error() {
  local title="$1"
  local message="$2"
  local data="$3"
  log::error "${title}: ${message}"
  rollbar::report 'error' "${title}" "${message}" "${data}"
}

# Reports warnings via rollbar.
# @param $1 Title for the report
# @param $2 Message to report
# @param $3 Additional data to report (format?)
rollbar::report_warning() {
  local title="$1"
  local message="$2"
  local data="$3"
  log::warn "${title}: ${message}"
  rollbar::report 'warning' "${title}" "${message}" "${data}"
}

# Creates an error trap that reports any failures to rollbar with the given
# title, message, and data.
#
# @example
# rollbar::error_trap \
#    "Title for the rollbar message"
#    "Body for the rollbar message"
#
# do_something_that_could_error
#
# rollbar::clear_trap
#
# @param $1 Title for the report
# @param $2 Message to report
# @param $3 Additional data to report (format?)
rollbar::error_trap() {
  local title=${1}
  local message=${2}
  local data=${3}
  local report_cmd="rollbar::report_error '${title}' '${message}' '${data}'"
  trap "$report_cmd" ERR
}

# Creates an error trap that reports and failures to rollbar as warnings.
# @param $1 Title for the report
# @param $2 Message to report
# @param $3 Additional data to report (format?)
rollbar::warning_trap() {
  local title=${1}
  local message=${2}
  local data=${3}
  local report_cmd="rollbar::report_warning '${title}' '${message}' '${data}'"
  trap "$report_cmd" ERR
}

# Creates an error trap that reports any failures to rollbar and then fatally
# exits with status code 1.
#
# @param $1 Title for the report
# @param $2 Message to report
# @param $3 Additional data to report (format?)
rollbar::fatal_trap() {
  local title=${1}
  local message=${2}
  local data=${3}
  local report_cmd="rollbar::report_error '${title}' '${message}' '${data}'"

  trap "$report_cmd; halter::halt" ERR
}


# Clears the previously set rollbar reporting error trap. See the example in the
# `rollbar::error_trap` function for usage.
rollbar::clear_trap() {
  trap - ERR
}

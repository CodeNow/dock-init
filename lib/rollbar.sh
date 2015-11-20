#!/bin/bash

source "${DOCK_INIT_BASE}"/lib/log.sh

# Module for handling reporting to rollbar within dock-init bash scripts. This
# module exposes various report_* and trap_* methods that can be used to easily
# ineteract and send messages to rollbar.
# @author Bryan Kendall
# @author Ryan Sandor Richards
# @module rollbar

# Ensure the module has a rollbar token
if [[ -n "${ROLLBAR_TOKEN}" ]]; then
  ROLLBAR_TOKEN=$(cat "$DOCK_INIT_BASE"/key/rollbar.token)
  export ROLLBAR_TOKEN
fi

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
  if [[ "$data" == "" ]]; then data="{}"; fi

  local json_trap="data='{}'; log::warn 'Invalid JSON Data was Passed with $title, $message';"
  trap '$json_trap' ERR
  echo "$data" | jq "." > /dev/null 2>&1
  trap - ERR

  local timestamp=''
  timestamp=$(date +'%s')
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
        "host": "'"${LOCAL_IP4_ADDRESS}"'"
      }
    }
  }';
  # trap a curl error here to print a fatal error.
  trap 'log::fatal "COULD NOT REPORT TO ROLLBAR"; exit 1' ERR
  curl -s -q -H "Content-Type: application/json" \
    -d "$payload" \
    "https://api.rollbar.com/api/1/item/" > /dev/null 2>&1
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
  rollbar::report "error" "${title}" "${message}" "${data}"
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
  rollbar::report "warning" "${title}" "${message}" "${data}"
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
  trap "$report_cmd; exit 1" ERR
}

# Clears the previously set rollbar reporting error trap. See the example in the
# `rollbar::error_trap` function for usage.
rollbar::clear_trap() {
  trap - ERR
}

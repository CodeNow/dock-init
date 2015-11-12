#!/bin/bash

ROLLBAR_TOKEN=`cat $DOCK_INIT_BASE/key/rollbar.token`
if [[ "$DONT_DELETE_KEYS" == "" ]]; then rm -f $DOCK_INIT_BASE/key/rollbar.token; fi

# report_to_rollbar "level" "title" "message" "data (a JSON object)"
report_to_rollbar () {
  echo `date` "[INFO] Reporting to Rollbar: $@"
  local level="$1"
  local title="$2"
  local message="$3"
  local data="$4"

  # verify that data is valid JSON
  if [[ "$data" == "" ]]; then data="{}"; fi
  trap "data='{}'; echo '`date` [WARN] Invalid JSON Data was Passed with $title, $message';" ERR
  echo "$data" | jq "." > /dev/null 2>&1
  trap - ERR

  local timestamp=`date +'%s'`
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
  trap 'echo `date` "[FATAL] COULD NOT REPORT TO ROLLBAR"; exit 1' ERR
  curl -s -q -H "Content-Type: application/json" -d "$payload" "https://api.rollbar.com/api/1/item/" > /dev/null 2>&1
  trap - ERR
  echo `date` "[INFO] Reported to Rollbar"
}

# report_warn_to_rollbar "title" "message"
report_warn_to_rollbar ()
{
  local title="$1"
  local message="$2"
  local data="$3"

  echo `date` "[WARN] $title: $message"
  report_to_rollbar "warning" "$title" "$message" "$data"
}

# report_err_to_rollbar "title" "message"
report_err_to_rollbar ()
{
  local title="$1"
  local message="$2"
  local data="$3"

  echo `date` "[ERROR] $title: $message"
  report_to_rollbar "error" "$title" "$message" "$data"
}

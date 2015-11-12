#!/bin/bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# DONT DELETE KEYS
DONT_DELETE_KEYS=true
export DONT_DELETE_KEYS

# BEFORE
DOCK_INIT_BASE="$DIR/.."
export DOCK_INIT_BASE

# BEFORE
echo $DIR/../key/rollbar.token
if [[ ! -e "$DIR/../key/rollbar.token" ]]; then
  echo "**** TEST FAILED: key/rollbar.token must be present"
  exit 1
fi

# BEFORE
if ! command -v jq > /dev/null; then
  echo "**** TEST FAILED: jq must be installed"
  exit 1
fi

. "$DIR/../util/rollbar.sh"

# Error Catcher
trap 'echo "**** TEST FAILED: $0:$LINENO"; exit 1' ERR

# test that reporting an error works
report_err_to_rollbar "Dock-Init: Test Error" "Testing error message."

# test that reporting a warning works
report_warn_to_rollbar "Dock-Init: Test Warning" "Testing warning messages."

# test that reporting should work with extra JSON data
bar="world"
data='{"foo":false, "hello":"'"${bar}"'"}'
report_err_to_rollbar "Dock-Init: Test Error with Data" "Testing error messages with data." "$data"
report_warn_to_rollbar "Dock-Init: Test Warning with Data" "Testing warning messages with data." "$data"

# test that reporting should work if invalid json was passed through
echo "**** MANUALLY VERIFY THAT AN INVALID JSON MESSAGE IS PRINTED HERE (3 LINES DOWN)"
data='{foo:false}'
message="Testing warning messages with data. The data element here should be an empty object."
report_warn_to_rollbar "Dock-Init: Test Warning with Bad Data" "$message" "$data"

echo "**** TEST COMPLETED SUCCESSFULLY!"

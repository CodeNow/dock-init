#!/bin/bash

# Unit tests for the `lib/util/rollbar.sh` module.

source "$DOCK_INIT_BASE/lib/util/rollbar.sh"
source "$DOCK_INIT_BASE/test/fixtures/shtub.sh"

describe 'util/rollbar.sh'
  describe 'rollbar::init'
    # before
      local token_file_contents='c0ffee'
      local _cat=$(which cat)
      stub::returns cat "$token_file_contents"
    # end

    it 'should export ROLLBAR_TOKEN'
      unset ROLLBAR_TOKEN
      rollbar::init
      assert equal "$ROLLBAR_TOKEN" "$token_file_contents"
    end

    it 'should not export if ROLLBAR_TOKEN is already set'
      local token='deadbeef'
      export ROLLBAR_TOKEN="$token"
      rollbar::init
      assert equal "$ROLLBAR_TOKEN" "$token"
    end

    # after
      cat::restore
    # end
  end # rollbar::init

  # Assume a faux token for the rest of the tests
  export ROLLBAR_TOKEN='deadbeef'
  export environment='test'

  describe 'rollbar::_get_payload'
    it 'should return valid json'
      local result=$(rollbar::_get_payload "level" "title" "message" "{}")
      echo "$result" | jq "." &> /dev/null
      assert equal "$?" '0'
    end

    it 'should return the correct json payload'
      local level='warn'
      local title='some title'
      local message='some message'
      local data='{"a":"b"}'
      local expected='{
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
      }'
      expected=$(echo $expected | jq ".")
      local result=$(rollbar::_get_payload "$level" "$title" "$message" "$data")
      result=$(echo $expected | jq ".")
      assert equal "$expected" "$result"
    end
  end # 'rollbar::_get_payload'

  describe 'rollbar::report'
    # before
      local payload_json='{"JSON":true}'
      stub 'rollbar::_get_payload'
      rollbar::_get_payload::returns "$payload_json"
      stub curl
      stub log::info
      stub log::fatal
      stub log::warn
      stub halter::halt
    # end

    it 'should set default data when it is empty'
      rollbar::report 'level' 'title' 'message'
      rollbar::_get_payload::called_with 'level' 'title' 'message' '{}'
    end

    it 'should set default data when passed invalid json'
      rollbar::report 'level' 'title' 'message' 'not-valid'
      rollbar::_get_payload::called_with 'level' 'title' 'message' '{}'
    end

    it 'should log a warning when passed invalid data json'
      rollbar::report 'level' 'title' 'message' 'not-valid'
      log::warn::called_with 'Invalid JSON Data'
    end

    it 'should report the error to rollbar'
      rollbar::report 'level' 'title' 'message'
      curl::called_with -s -q -H "Content-Type: application/json" \
        -d '{"JSON":true}' \
        "https://api.rollbar.com/api/1/item/"
    end

    it 'should halter if curl fails'
      curl::errors
      rollbar::report 'level' 'title' 'message'
      halter::halt::called_once
    end

    it 'should log if curl fails'
      curl::errors
      rollbar::report 'level' 'title' 'message'
      log::fatal::called_with "COULD NOT REPORT TO ROLLBAR"
    end

    it 'should log that the error has been reported'
      curl::returns ''
      rollbar::report 'level' 'title' 'message'
      log::info::called_with "Error Reported"
    end

    # after
      halter::halt::restore
      log::info::restore
      log::fatal::restore
      log::warn::restore
      curl::restore
      rollbar::_get_payload::restore
    # end
  end # 'rollbar::report'

  # Stub report and the logger functions for the rest of the suite
  stub rollbar::report
  stub log::warn
  stub log::error

  describe 'rollbar::report_error'
    it 'should report as an error'
      rollbar::report_error 'title' 'message' '{}'
      rollbar::report::called_with 'error' 'title' 'message' '{}'
    end
  end # 'rollbar::report_error'

  describe 'rollbar::report_warning'
    it 'should report as a warning'
      rollbar::report_warning 'title' 'message' '{}'
      rollbar::report::called_with 'warning' 'title' 'message' '{}'
    end
  end # rollbar::report_warning

  describe 'traps'
    # before
      stub trap
    # end

    describe 'rollbar::error_trap'
      it 'should set the correct trap'
        rollbar::error_trap 'title' 'message' 'data'
        trap::called_with "rollbar::report_error 'title' 'message' 'data' ERR"
      end
    end # rollbar::error_trap

    describe 'rollbar::warning_trap'
      it 'should set the correct trap'
        rollbar::warning_trap 'title' 'message' 'data'
        trap::called_with "rollbar::report_warning 'title' 'message' 'data' ERR"
      end
    end # rollbar::warning_trap

    describe 'rollbar::fatal_trap'
      it 'should set the correct trap'
        rollbar::fatal_trap 'title' 'message' 'data'
        local cmd="rollbar::report_error 'title' 'message' 'data'"
        trap::called_with "$cmd; halter::halt ERR"
      end
    end # rollbar::fatal_trap

    describe 'rollbar::clear_trap'
      it 'should clear the trap'
        rollbar::clear_trap
        trap::called_with '- ERR'
      end
    end # rollbar::clear_trap

    # after
      trap::restore
    # end
  end

  rollbar::report::restore
  log::warn::restore
  log::error::restore
end

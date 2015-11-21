#!/bin/bash

# Unit tests for the `lib/util/backoff.sh` module.
# @author Ryan Sandor Richards

source "$DOCK_INIT_BASE/lib/util/log.sh"

describe 'util/log.sh'
  # before
    local fake_date='some-fake-date-wow'
    date_stub() { echo "$fake_date"; }
    stub::set 'date' date_stub

    local had_log_level=0
    local old_log_level
    if [[ "$LOG_LEVEL" ]]; then
      had_log_level=1
      old_log_level="$LOG_LEVEL"
      unset $LOG_LEVEL
    fi
  # end

  describe 'log::_get_log_level_int'
    describe 'with given level'
      it 'should print 60 for fatal'
        local expected=60
        local result=$(log::_get_log_level_int 'fatal')
        assert equal "$expected" "$result"
      end

      it 'should print 50 for error'
        local expected=50
        local result=$(log::_get_log_level_int 'error')
        assert equal "$expected" "$result"
      end

      it 'should print 40 for warn'
        local expected=40
        local result=$(log::_get_log_level_int 'warn')
        assert equal "$expected" "$result"
      end

      it 'should print 30 for info'
        local expected=30
        local result=$(log::_get_log_level_int 'info')
        assert equal "$expected" "$result"
      end

      it 'should print 20 for debug'
        local expected=20
        local result=$(log::_get_log_level_int 'debug')
        assert equal "$expected" "$result"
      end

      it 'should print 10 for trace'
        local expected=10
        local result=$(log::_get_log_level_int 'trace')
        assert equal "$expected" "$result"
      end

      it 'should print 0 for none'
        local expected=0
        local result=$(log::_get_log_level_int 'none')
        assert equal "$expected" "$result"
      end

      it 'should ignore case'
        local expected=20
        local result=$(log::_get_log_level_int 'dEbuG')
        assert equal "$expected" "$result"
      end
    end # with given level

    describe 'with LOG_LEVEL'
      it 'should use the LOG_LEVEL variable'
        if [ -z ${LOG_LEVEL+x} ]; then
          export LOG_LEVEL="debug"
          local expected=20
          local result=$(log::_get_log_level_int)
          assert equal "$expected" "$result"
          unset LOG_LEVEL
        else
          local old_log_level="$LOG_LEVEL"
          export LOG_LEVEL="warn"
          local expected=40
          local result=$(log::_get_log_level_int)
          assert equal "$expected" "$result"
          export LOG_LEVEL="$old_log_level"
        fi
      end
    end # with LOG_LEVEL

    describe 'without given level or LOG_LEVEL'
      it 'should use info'
        if [ -z ${LOG_LEVEL+x} ]; then
          local expected=30
          local result=$(log::_get_log_level_int)
          assert equal "$expected" "$result"
        else
          local old_log_level="$LOG_LEVEL"
          unset LOG_LEVEL
          local expected=30
          local result=$(log::_get_log_level_int)
          export LOG_LEVEL="$old_log_level"
        fi
      end
    end # without given level or LOG_LEVEL
  end # log::_get_log_level_int

  describe 'log::message'
    it 'should correctly format the message'
      local level='FATAL'
      local message='some long message wheeeeee'
      local expected="$fake_date [$level] $message"
      local result=$(log::message $level "$message")
      assert equal "$expected" "$result"
    end

    it 'should not print if the level lower than LOG_LEVEL'
      if [ -z ${LOG_LEVEL+x} ]; then
        export LOG_LEVEL='fatal'
        assert equal '' "$(log::message 'info' 'should print nothing')"
        unset LOG_LEVEL
      else
        local old_log_level="$LOG_LEVEL"
        export LOG_LEVEL='fatal'
        assert equal '' "$(log::message 'info' 'should print nothing')"
        export LOG_LEVEL="$old_log_level"
      fi
    end
  end # log::message

  describe 'helpers'
    describe 'log::fatal'
      it 'should echo the correct message'
        local message='snksnksn222kks'
        local expected="$fake_date [FATAL] $message"
        local result=$(log::fatal "$message")
        assert equal "$expected" "$result"
      end
    end # log::fatal

    describe 'log::error'
      it 'should echo the correct message'
        local message='snksnksn222kks'
        local expected="$fake_date [ERROR] $message"
        local result=$(log::error "$message")
        assert equal "$expected" "$result"
      end
    end # log::error

    describe 'log::warn'
      it 'should echo the correct message'
        local message='snksnksn222kks'
        local expected="$fake_date [WARN] $message"
        local result=$(log::warn "$message")
        assert equal "$expected" "$result"
      end
    end # log::warn

    describe 'log::info'
      it 'should echo the correct message'
        local message='snksnksn222kks'
        local expected="$fake_date [INFO] $message"
        local result=$(log::info "$message")
        assert equal "$expected" "$result"
      end
    end # log::info

    describe 'log::debug'
      it 'should echo the correct message'
        local message='snksnksn222kks'
        local expected="$fake_date [DEBUG] $message"
        local result=$(log::debug "$message")
        assert equal "$expected" "$result"
      end
    end # log::debug

    describe 'log::trace'
      it 'should echo the correct message'
        local message='snksnksn222kks'
        local expected="$fake_date [TRACE] $message"
        local result=$(log::trace "$message")
        assert equal "$expected" "$result"
      end
    end # log::trace
  end # helpers

  # after
    stub::restore 'date'
    if (( had_log_level == 1 )); then
      export LOG_LEVEL="$old_log_level"
    fi
  # end
end # util/log.sh

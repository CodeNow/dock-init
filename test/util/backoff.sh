#!/bin/bash

# Unit tests for the `lib/util/backoff.sh` module.
# @author Ryan Sandor Richards

source $DOCK_INIT_BASE/lib/util/backoff.sh

describe 'dock-init'
  describe 'util'
    describe 'backoff'
      it 'should execute the action'
        local expected='action taken wow20030'
        action() { echo "$expected"; }
        local result=$(backoff action)
        assert equal "$result" "$expected"
      end

      it 'should pass the attempt number'
        local expected='attempt:1'
        action() { echo "attempt:${1}"; }
        local result=$(backoff action)
        assert equal "$result" "$expected"
      end

      it 'should pass the timeout'
        local expected='timeout:1'
        action() { echo "timeout:${2}"; }
        local result=$(backoff action)
        assert equal "$result" "$expected"
      end

      it 'should retry on failure'
        stub::set 'sleep'
        local max_attempts=5
        local counter=0
        action() {
          local attempt="${1}"
          counter=$(( counter + 1 ))
          if (( attempt < max_attempts )); then
            return 1;
          fi
        }
        backoff action
        assert equal "$counter" "$max_attempts"
        stub::restore 'sleep'
      end

      it 'should sleep between tries'
        local did_sleep=0
        sleep_stub() { did_sleep=1; }
        stub::set 'sleep' sleep_stub
        action() {
          local attempt="${1}"
          if (( attempt == 1 )); then
            return 1
          fi
        }
        backoff action
        assert equal "$did_sleep" "1"
        stub::restore 'sleep'
      end

      it 'should exponentially back off'
        local timeouts=""
        local max_attempts=4
        sleep_stub() { timeouts+="${1} "; }
        stub::set 'sleep' sleep_stub
        action() {
          if (( ${1} < max_attempts )); then
            return 1
          fi
        }
        backoff action
        assert equal "1 2 4 " "$timeouts"
        stub::restore 'sleep'
      end

      it 'should increase the number of attempts'
        local max_attempts=5
        local attempts=""
        action() {
          attempts+="${1} ";
          if (( $1 < max_attempts )); then return 1; fi
        }
        stub::set 'sleep'
        backoff action
        assert equal "1 2 3 4 5 " "$attempts"
        unstub_command 'sleep'
      end
    end #backoff
  end #util
end #dock-init

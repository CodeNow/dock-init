#!/bin/bash

# Unit tests for the `lib/util/backoff.sh` module.
# @author Ryan Sandor Richards

source "$DOCK_INIT_BASE/lib/util/backoff.sh"
source "$DOCK_INIT_BASE/test/fixtures/stub.sh"

describe 'util/backoff.sh'
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
    stub::restore 'sleep'
  end

  it 'should run a failure function'
    local storage=""
    action() {
      if (( ${1} == 2 )); then
        storage+=" world"
      else
        false
      fi
    }
    failure() {
      storage+="hello"
    }
    stub::set 'sleep'
    backoff action failure
    assert equal "hello world" "$storage"
    stub::restore 'sleep'
  end

  it 'should skip failure function if not a function'
    local storage=""
    action() {
      if (( ${1} == 2 )); then
        storage+="hello "
      else
        false
      fi
    }
    success() {
      storage+="world"
    }
    stub::set 'sleep'
    backoff action 'OMG' success
    assert equal "hello world" "$storage"
    stub::restore 'sleep'
  end

  it 'should skip success function if not a function'
    local storage=""
    action() {
      if (( ${1} == 2 )); then
        storage+="hello"
      else
        false
      fi
    }
    failure() {
      storage+="world"
    }
    stub::set 'sleep'
    backoff action failure 'WEE'
    assert equal "worldhello" "$storage"
    stub::restore 'sleep'
  end

  it 'should run a success function'
    local storage=""
    action() {
      if (( ${1} == 2 )); then
        storage+="cruel "
      else
        false
      fi
    }
    failure() {
      storage+="goodnight "
    }
    success() {
      storage+="world"
    }
    stub::set 'sleep'
    backoff action failure success
    # failure is run first, then action (a second time), then success
    assert equal "goodnight cruel world" "$storage"
    stub::restore 'sleep'
  end
end # util/backoff.sh

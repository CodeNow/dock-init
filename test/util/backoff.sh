#!/bin/bash

# Unit tests for the `lib/util/backoff.sh` module.
# @author Ryan Sandor Richards

source "$DOCK_INIT_BASE/lib/util/backoff.sh"
source "$DOCK_INIT_BASE/test/fixtures/shtub.sh"

describe 'util/backoff.sh'
  before_each() {
    stub action
    stub sleep
  }

  after_each() {
    action::restore
    sleep::restore
  }

  it 'should execute the action'
    before_each
    local expected='action taken wow20030'
    action::returns "$expected"
    assert equal "$(backoff action)" "$expected"
    after_each
  end

  it 'should pass the attempt number and next timeout to the action'
    before_each
    action::errors ; action::on_call 6 true
    backoff action
    action::called_with 6 32
    after_each
  end

  it 'should retry on failure'
    before_each
    action::errors ; action::on_call 5 true
    backoff action
    action::called 5
    after_each
  end

  it 'should sleep between tries'
    before_each
    action::errors ; action::on_call 4 true
    backoff action
    sleep::called 3
    after_each
  end

  it 'should exponentially back off'
    before_each
    action::errors
    action::on_call 10 true
    backoff action
    action::called_with 10 512
    after_each
  end

  it 'should run a failure function'
    before_each
    stub failure
    action::errors ; action::on_call 2 true
    backoff action failure
    failure::called_once
    failure::restore
    after_each
  end

  it 'should run a success function'
    before_each
    action::exec true
    stub failure
    stub success
    backoff action failure success
    success::called_once
    failure::restore
    success::restore
    after_each
  end
end # util/backoff.sh

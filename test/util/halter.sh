#!/bin/bash

# Unit tests for the `lib/util/halter.sh` module.

source "$DOCK_INIT_BASE/lib/util/halter.sh"
source "$DOCK_INIT_BASE/test/fixtures/shtub.sh"

describe 'halter.sh'
  describe 'halt'
    stub halt
    stub exit
    unset USE_EXIT

    it 'should exit if USE_EXIT is defined'
      export USE_EXIT=true
      halter::halt
      exit::called_with 1
      halt::not_called
    end

    # reset stubs
    exit::restore
    stub exit

    it 'should halt if USE_EXIT is not defined'
      unset USE_EXIT
      halter::halt
      halt::called_once
      exit::not_called
    end

    unset USE_EXIT
    halt::restore
    exit::restore
  end # halt
end # halter.sh

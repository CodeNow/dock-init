#!/bin/bash

# Unit tests for the `lib/util/halter.sh` module.

source "$DOCK_INIT_BASE/lib/util/halter.sh"
source "$DOCK_INIT_BASE/test/fixtures/shtub.sh"

describe 'halter.sh'
  describe 'halt'
    stub halt
    stub exit
    unset HALT

    it 'should halt if halt==true'
      export HALT="true"
      halter::halt
      halt::called_once
    end

    it 'should exit if HALT not set'
    unset HALT
      halter::halt
      exit::called_with 1
    end

    unset HALT
    halt::restore
    exit::restore
  end # halt
end # halter.sh

#!/bin/bash

# Unit tests for the `lib/dock.sh` module.
# @author Anandkumar Patel

source "$DOCK_INIT_BASE/lib/dock.sh"
source "$DOCK_INIT_BASE/test/fixtures/shtub.sh"

describe 'dock.sh'
  stub log::info

  describe 'dock::set_hostname'
    it 'should add org to hostname'
      stub hostname
      hostname::returns 'ip-10-17-38-1'
      export ORG_ID='123123123'
      dock::set_hostname
      hostname::called_with "ip-10-17-38-1.123123123"
      hostname::restore
      unset ORG_ID
    end
  end

  log::info::restore
end # dock.sh

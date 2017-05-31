#!/bin/bash

source "$DOCK_INIT_BASE/lib/consul.sh"
source "$DOCK_INIT_BASE/test/fixtures/shtub.sh"

describe 'consul.sh'
  stub log::info
  stub rollbar::fatal_trap

  describe 'configure_consul_template'
    stub consul-template

    it 'should wrap the configuration in a fatal trap'
      consul::configure_consul_template
      rollbar::fatal_trap::called_once
    end

    it 'generate the consul-template configuration'
      consul::configure_consul_template
      consul-template::called_with '-once -template'
    end

    it 'should have exposed VAULT_TOKEN'
      export VAULT_TOKEN='MOCK-TOKEN'
      consul::configure_consul_template
      assert equal "$VAULT_TOKEN" 'MOCK-TOKEN'
    end

    unset VAULT_TOKEN
    consul-template::restore
  end # configure_consul_template

  log::info::restore
  rollbar::fatal_trap::restore
end # consul.sh

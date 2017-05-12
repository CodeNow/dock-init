#!/bin/bash

# Unit tests for the `lib/consul.sh` module.

source "$DOCK_INIT_BASE/lib/consul.sh"
source "$DOCK_INIT_BASE/test/fixtures/shtub.sh"

describe 'consul.sh'
  stub log::info
  stub rollbar::fatal_trap

  describe 'configure_consul_template'
    stub consul::get
    stub consul-template
    stub cat

    consul::get::returns 'TEST-NODE-ENV'
    cat::returns 'MOCK-TOKEN'

    it 'should wrap the configuration in a fatal trap'
      consul::configure_consul_template
      rollbar::fatal_trap::called_once
    end

    it 'should fetch the node environment'
      consul::configure_consul_template
      consul::get::called_with 'node/env'
    end

    it 'should read in the vault token'
      consul::configure_consul_template
      cat::called_with "${DOCK_INIT_BASE}/consul-resources/vault/TEST-NODE-ENV/user-vault-auth-token"
    end

    it 'generate the consul-template configuration'
      consul::configure_consul_template
      consul-template::called_with '-once -template'
    end

    it 'should have exposed VAULT_TOKEN'
      consul::configure_consul_template
      assert equal "$VAULT_TOKEN" 'MOCK-TOKEN'
    end

    unset VAULT_TOKEN
    consul::get::restore
    consul-template::restore
    cat::restore
  end # configure_consul_template

  log::info::restore
  rollbar::fatal_trap::restore
end # dock.sh

#!/bin/bash

# Tests for the vault module.

source "$DOCK_INIT_BASE/lib/vault.sh"
source "$DOCK_INIT_BASE/test/fixtures/stub.sh"

describe 'vault.sh'
  describe 'vault::connect'
    it 'it should call backoff with appropriate arguments'
      local storage=""
      backoffStub () {
        storage+="$@"
      }
      stub::set backoff backoffStub

      vault::connect
      assert equal "vault::connect_backoff vault::_connect_backoff_failure" "$storage"

      stub::restore backoff
    end
  end

  describe 'vault::connect_backoff'
    it 'it should curl for the vault address'
      local storage=""
      curlStub () {
        storage+="$@"
      }
      stub::set curl curlStub
      VAULT_ADDR="foo"

      vault::connect_backoff
      assert equal "-s foo/v1/auth/seal-status" "$storage"

      stub::restore curl
      unset VAULT_ADDR
    end
  end

  describe 'vault::_connect_backoff_failure'
    it 'it should report to rollbar'
      local storage=""
      rollbarReportStub () {
        storage+="$@"
      }
      stub::set rollbar::report_warning rollbarReportStub
      VAULT_ADDR="foo"

      vault::_connect_backoff_failure 1
      assert equal 'Vault Start: Cannot Reach Vault Server Attempting to reach local Vault and failing. {"vault_addr":"foo","attempt":1}' "$storage"

      stub::restore rollbar::report_warning
      unset VAULT_ADDR
    end
  end

  describe 'vault::configure'
    it 'it should generate a config for vault'
      local storage=""
      consulTemplateStub () {
        storage+="$@"
      }
      stub::set consul-template consulTemplateStub
      VAULT_CONFIG="bar"

      vault::configure
      assert equal "-once -template=$DOCK_INIT_BASE/consul-resources/templates/vault.hcl.ctmpl:bar" "$storage"

      stub::restore consul-template
      unset VAULT_CONFIG
    end
  end

  describe 'vault::unlock'
    it 'it should unseal vault and get the status'
      local storage=""
      traceStub () {
        storage+="$@ "
      }
      local calls=0
      vaultStub () {
        storage+="$@ "
        calls=$(( calls + 1 ))
        if [ $calls == 3 ]; then
          stub::set log::trace traceStub
        fi
        if [ $calls == 4 ]; then
          echo "ran status"
        fi
      }
      stub::set vault vaultStub
      catStub () {
        echo "hi"
      }
      stub::set cat catStub

      vault::unlock
      assert equal "unseal hi unseal hi unseal hi Getting Vault Status Vault Status ran status " "$storage"

      stub::restore vault
      stub::restore cat
      stub::restore log::trace
    end
  end
end

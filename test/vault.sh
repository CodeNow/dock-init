#!/bin/bash

# Unit tests for the `lib/vault.sh` module.
# @author Anandkumar Patel

source "$DOCK_INIT_BASE/lib/vault.sh"
source "$DOCK_INIT_BASE/test/fixtures/shtub.sh"

describe 'vault.sh'
  stub log::info
  stub exit

  describe 'vault::create_s3_policy'
    local bucket='ice'
    export ORG_ID='runnabear'
    stub vault
    stub rollbar::report_error

    it 'should run vault'
      local policy_location="${DOCK_INIT_BASE}/vault-resources/s3.policy.json"

      vault::create_s3_policy "${bucket}"
      vault::called_with "write aws/roles/s3-${ORG_ID} policy"
    end

    it 'should create policy'
      local policy_location="${DOCK_INIT_BASE}/vault-resources/s3.policy.json"

      vault::create_s3_policy "${bucket}"
      grep -q '"arn:aws:s3:::ice"$' $policy_location
      assert equal "0" "$?"
      grep -q "arn:aws:s3:::ice/runnabear/*" $policy_location
      assert equal "0" "$?"
    end

    it 'should report errors on failure'
      vault::errors
      vault::create_s3_policy
      rollbar::report_error::called
    end

    it 'should exit 1 on failure'
      vault::errors
      vault::create_s3_policy
      exit::called_with "1"
    end

    unset ORG_ID
    vault::restore
    rollbar::report_error::restore
  end # end vault::create_s3_policy

  describe 'vault::set_s3_keys'
    local bucket='ice'
    export ORG_ID='runnabear'
    unset S3_ACCESS_KEY
    unset S3_SECRET_KEY
    stub vault
    stub rollbar::report_error

    it 'should run vault'
      vault::set_s3_keys
      vault::called_with "read aws/creds/s3-${ORG_ID}"
    end

    it 'should set S3_ACCESS_KEY'
      local key='AKIAIOMYUTSLGJOGLHTQ'
      vault::returns "lease_duration 3600 access_key ${key}"
      vault::set_s3_keys
      assert equal "${key}" "$S3_ACCESS_KEY"
    end

    it 'should set S3_SECRET_KEY'
      local key='BK9++oBABaBvRKcT5KEF69xQGcH7ZpPRF3oqVEv7'
      vault::returns "lease_duration 3600 secret_key ${key}"
      vault::set_s3_keys
      assert equal "${key}" "$S3_SECRET_KEY"
    end

    it 'should report errors on failure'
      vault::errors
      vault::set_s3_keys
      rollbar::report_error::called
    end

    it 'should exit 1 failure'
      vault::errors
      vault::set_s3_keys
      exit::called_with "1"
    end

    unset ORG_ID
    unset S3_ACCESS_KEY
    unset S3_SECRET_KEY
    vault::restore
    rollbar::report_error::restore
  end # end vault::set_s3_keys

  exit::restore
end # upstart.sh

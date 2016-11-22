#!/bin/bash

# Unit tests for the `lib/container.sh` module.
# @author Anandkumar Patel

source "$DOCK_INIT_BASE/lib/container.sh"
source "$DOCK_INIT_BASE/test/fixtures/shtub.sh"

describe 'container.sh'
  stub log::info

  describe 'container::_start_swarm_container'
    local swarm_version='1.0.0'
    export CONSUL_HOSTNAME='consul_hostname'
    export CONSUL_PORT='consul_port'
    export HOST_IP='host_ip'
    stub::returns 'consul::get' "$swarm_version"
    stub docker
    stub rollbar::report_error

    it 'should run docker container'
      container::_start_swarm_container
      docker::called
    end

    it 'should report errors on failure'
      docker::errors
      container::_start_swarm_container
      rollbar::report_error::called
    end

    it 'should return 1 on failure'
      docker::errors
      container::_start_swarm_container
      assert equal "$?" "1"
    end

    unset CONSUL_HOSTNAME
    unset CONSUL_PORT
    unset HOST_IP
    docker::restore
    consul::get::restore
    rollbar::report_error::restore
  end # end container::_start_swarm_container

  describe 'container::_start_registry_container'
    local registry_version='1.0.0'
    local region="${registry_version}"
    local bucket="${registry_version}"
    export ORG_ID='runnabear'
    export S3_ACCESS_KEY='thatKey'
    export S3_SECRET_KEY='datSecret'
    stub::returns 'consul::get' "$registry_version"
    stub docker
    stub vault::create_s3_policy
    stub vault::set_s3_keys
    stub rollbar::report_error

    it 'should run docker container'
      container::_start_registry_container
      docker::called
      vault::create_s3_policy::called_with "$bucket"
      vault::set_s3_keys::called
    end

    it 'should report errors on failure'
      docker::errors
      container::_start_registry_container
      rollbar::report_error::called
    end

    it 'should return 1 on failure'
      docker::errors
      container::_start_registry_container
      assert equal "$?" "1"
    end

    unset ORG_ID
    unset S3_ACCESS_KEY
    unset S3_SECRET_KEY
    docker::restore
    consul::get::restore
    rollbar::report_error::restore
  end # _start_registry_container

  describe 'container::_start_cadvisor_container'
    local cadvisor_version='v0.24.1'
    stub docker
    stub rollbar::report_error

    it 'should run docker container'
      container::_start_cadvisor_container
      docker::called
    end

    it 'should report errors on failure'
      docker::errors
      container::_start_cadvisor_container
      rollbar::report_error::called
    end

    it 'should return 1 on failure'
      docker::errors
      container::_start_cadvisor_container
      assert equal "$?" "1"
    end

    docker::restore
    rollbar::report_error::restore
  end # end container::_start_cadvisor_container

  describe 'container::_start_node_exporter_container'
    local cadvisor_version='v0.24.1'
    stub docker
    stub rollbar::report_error

    it 'should run docker container'
      container::_start_node_exporter_container
      docker::called
    end

    it 'should report errors on failure'
      docker::errors
      container::_start_node_exporter_container
      rollbar::report_error::called
    end

    it 'should return 1 on failure'
      docker::errors
      container::_start_node_exporter_container
      assert equal "$?" "1"
    end

    docker::restore
    rollbar::report_error::restore
  end # end container::_start_node_exporter_container

  describe 'container::start'
    stub container::_start_registry_container
    stub container::_start_cadvisor_container
    stub container::_start_node_exporter_container
    stub container::_start_swarm_container
    stub upstart::start_docker
    stub docker

    it 'should start all required containers'
    container::start
    container::_start_registry_container::called
    container::_start_cadvisor_container::called
    container::_start_node_exporter_container::called
    container::_start_swarm_container::called
    upstart::start_docker::called

    container::_start_registry_container::restore
    container::_start_cadvisor_container::restore
    container::_start_node_exporter_container::restore
    container::_start_swarm_container::restore
  end # end container::start
end # container.sh

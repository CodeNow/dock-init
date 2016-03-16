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
      local expectedArgs="run -d --restart=always --name swarm"
      expectedArgs+=" swarm:${swarm_version}"
      expectedArgs+=" join --addr=host_ip:4242"
      expectedArgs+=" consul://${CONSUL_HOSTNAME}:${CONSUL_PORT}/swarm"
      container::_start_swarm_container
      docker::called_with "$dockerArgs"
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
      local expectedArgs="docker run"
      expectedArgs+=" swarm:${registry_version}"
      expectedArgs+="-d --restart=always --name ${image_name}"
      expectedArgs+="-p 80:5000"
      expectedArgs+="-e REGISTRY_HTTP_SECRET=${ORG_ID}"
      expectedArgs+="-e REGISTRY_STORAGE=s3"
      expectedArgs+="-e REGISTRY_STORAGE_S3_ACCESSKEY=${S3_ACCESS_KEY}"
      expectedArgs+="-e REGISTRY_STORAGE_S3_BUCKET=${bucket}"
      expectedArgs+="-e REGISTRY_STORAGE_S3_REGION=${region}"
      expectedArgs+="-e REGISTRY_STORAGE_S3_ROOTDIRECTORY=/${ORG_ID}"
      expectedArgs+="-e REGISTRY_STORAGE_S3_SECRETKEY=${S3_SECRET_KEY}"
      expectedArgs+="${name}:${version}"
      container::_start_registry_container

      docker::called_with "$dockerArgs"

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
end # upstart.sh

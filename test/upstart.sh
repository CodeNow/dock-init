#!/bin/bash

# Unit tests for the `lib/upstart.sh` module.
# @author Anandkumar Patel

source "$DOCK_INIT_BASE/lib/upstart.sh"
source "$DOCK_INIT_BASE/test/fixtures/shtub.sh"

describe 'upstart.sh'
  stub log::info

  describe 'upstart::start_swarm_container'
    local swarm_version='1.0.0'
    export CONSUL_HOSTNAME='consul_hostname'
    export CONSUL_PORT='consul_port'
    export HOST_IP='host_ip'
    stub::returns 'upstart::service_version' "$swarm_version"
    stub docker
    stub rollbar::report_error

    it 'should run docker container'
      local expectedArgs="run -d --restart=always --name swarm"
      expectedArgs+=" swarm:${swarm_version}"
      expectedArgs+=" join --addr=host_ip:4242"
      expectedArgs+=" consul://${CONSUL_HOSTNAME}:${CONSUL_PORT}/swarm"
      upstart::start_swarm_container
      docker::called_with "$dockerArgs"
    end

    it 'should report errors on failure'
      docker::errors
      upstart::start_swarm_container
      rollbar::report_error::called
    end

    it 'should return 1 on failure'
      docker::errors
      upstart::start_swarm_container
      assert equal "$?" "1"
    end

    unset CONSUL_HOSTNAME
    unset CONSUL_PORT
    unset HOST_IP
    docker::restore
    upstart::service_version::restore
    rollbar::report_error::restore
  end

  describe 'upstart::upstart_service'
    stub rollbar::warning_trap
    stub rollbar::clear_trap

    it 'should start the given service'
      stub service
      local service_name='foobar'
      upstart::upstart_service "$service_name"
      service::called_with "$service_name restart"
      service::restore
    end

    rollbar::warning_trap::restore
    rollbar::clear_trap::restore
  end

  describe 'upstart::upstart_services_with_backoff_params'
    it 'should start all our services'
      local storage=""
      serviceStub() { storage+="$@ "; }
      stub::exec upstart::upstart_named_service serviceStub
      stub::exec upstart::upstart_service serviceStub

      local attempt=8
      upstart::upstart_services_with_backoff_params $attempt

      local expected="filibuster 8 "
      expected+="krain 8 charon 8 docker-listener 8 datadog-agent 8 "

      assert equal "$expected" "$storage"

      upstart::upstart_named_service::restore
      upstart::upstart_service::restore
    end
  end

  describe 'upstart::pull_image_builder'
    local image_builder_version='v1.2.3'
    stub rollbar::report_warning
    stub docker
    stub::returns upstart::service_version "$image_builder_version"

    it 'should attempt to pull image builder'
      local registry="registry.runnable.com/runnable/image-builder"
      upstart::pull_image_builder 1
      docker::called_with "pull $registry:$image_builder_version"
    end

    it 'should return 1 on pull failure'
      docker::errors
      upstart::pull_image_builder 1
      assert equal "$?" "1"
    end

    it 'should report a warning on pull failure'
      docker::errors
      upstart::pull_image_builder 222
      rollbar::report_warning::called_with \
        "Dock-Init: Cannot Upstart Services" \
        "Attempting to upstart the services and failing." \
        '{"attempt":222}'
    end

    # docker::restore
    rollbar::report_warning::restore
    upstart::service_version::restore
  end

  log::info::restore
end # upstart.sh

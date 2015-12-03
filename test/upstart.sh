#!/bin/bash

# Unit tests for the `lib/upstart.sh` module.
# @author Anandkumar Patel

source "$DOCK_INIT_BASE/lib/upstart.sh"
source "$DOCK_INIT_BASE/test/fixtures/stub.sh"

describe 'upstart.sh'
  describe 'upstart::start_swarm_container'
    it 'should run docker container'
      CONSUL_HOSTNAME='consul_hostname'
      CONSUL_PORT='consul_port'
      HOST_IP='host_ip'
      local dockerArgs=0
      docker_stub() { dockerArgs=$@; }
      stub::set 'docker' docker_stub

      service_version_stub() { echo '1.0.0'; }
      stub::set 'upstart::service_version' service_version_stub

      upstart::start_swarm_container

      local expectedArgs="run -d --restart=always swarm:1.0.0 join"
      expectedArgs="${expectedArgs} --addr=host_ip:4242"
      expectedArgs="${expectedArgs} consul://consul_hostname:consul_port/swarm"

      assert equal "$dockerArgs" "$expectedArgs"

      stub::restore 'docker'
      stub::restore 'upstart::service_version'

      unset CONSUL_HOSTNAME
      unset CONSUL_PORT
      unset HOST_IP
    end
  end
end # upstart.sh

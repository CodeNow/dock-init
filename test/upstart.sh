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

  describe 'upstart::upstart_service'
    it 'should start the given service'
      local storage=""
      serviceStub() { storage+="$@"; }
      stub::set 'service' serviceStub

      upstart::upstart_service 'foobar'

      assert equal "foobar restart" "$storage"

      stub::restore 'service'
    end
  end

  describe 'upstart::upstart_services'
    it 'should start all our services'
      local storage=""
      serviceStub() { storage+="$@ "; }
      stub::set upstart::upstart_named_service serviceStub
      stub::set upstart::upstart_service serviceStub

      local attempt=8
      upstart::upstart_services $attempt

      assert equal "filibuster 8 krain 8 charon 8 docker-listener 8 datadog-agent 8 " "$storage"

      stub::restore upstart::upstart_named_service
      stub::restore upstart::upstart_service
    end
  end
end # upstart.sh

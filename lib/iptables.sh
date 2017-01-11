#!/bin/bash

source "${DOCK_INIT_BASE}/lib/util/log.sh"

iptables::run_rules() {
  log::info "setting up iptable rules"
  # drop pings
  iptables -I INPUT -p icmp --icmp-type echo-request -m state --state ESTABLISHED -j DROP

  # prevent containers from talking to host
  iptables -I INPUT -s ${DOCKER_NETWORK} -d 10.0.0.0/8 -m state --state NEW -j DROP

  # drop all new traffic from container ip to runnable infra
  iptables -I FORWARD -s ${DOCKER_NETWORK} -d 10.0.0.0/8 -m state --state NEW -j DROP
  # log container traffic for PSAD
  iptables -I FORWARD -s ${DOCKER_NETWORK} -j LOG
  # drop all local container to container traffic
  iptables -I FORWARD -s ${DOCKER_NETWORK} -d ${DOCKER_NETWORK} -j DROP
  # allow consul access (should be before drop)
  iptables -I FORWARD -s ${DOCKER_NETWORK} -d ${CONSUL_HOSTNAME} -j ACCEPT

  DNS_IP=`iptables::_find_aws_dns_ip`
  # allow aws DNS server queries (must be first)
  iptables -I FORWARD -s ${DOCKER_NETWORK} -d ${DNS_IP} -j ACCEPT

  # drop all new traffic from container to runnable infra
  iptables -I OUTPUT -s ${DOCKER_NETWORK} -d 10.0.0.0/8 -m state --state NEW -j DROP
}

iptables::_find_aws_dns_ip() {
  cat /etc/resolv.conf | grep name | cut -d' ' -f 2
}

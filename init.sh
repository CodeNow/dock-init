#!/bin/bash

# init.sh
# Ryan Sandor Richards
#
# This is the primary dock initialization script that is executed when a dock
# is provisioned via shiva. It calls the `upstart.sh` script and attempts to
# upstart services. If the upstart fails, it will retry (indefinitely with an
# exponential backoff.

DOCK_INIT_LOG_PATH=/var/log/dock-init.log
CERT_SCRIPT=/opt/runnable/dock-init/cert.sh
UPSTART_SCRIPT=/opt/runnable/dock-init/upstart.sh

REDIS_PORT_PATH=/opt/runnable/redis_port
REDIS_IPADDRESS_PATH=/opt/runnable/redis_ipaddress
RABBITMQ_HOSTNAME_PATH=/opt/runnable/rabbitmq_hostname
RABBITMQ_PORT_PATH=/opt/runnable/rabbitmq_port
RABBITMQ_USERNAME_PATH=/opt/runnable/rabbitmq_username
RABBITMQ_PASSWORD_PATH=/opt/runnable/rabbitmq_password

DOCKER_LISTENER_CONF=/etc/init/docker-listener.conf
SAURON_CONF=/etc/init/sauron.conf

# Replaces an env directive in the given upstart configuration
# $1 - Path to the upstart configuration
# $2 - Environment to replace
# $3 - Path to the value for the environment variable
replace_env() {
  local line=$(grep -n "env $2=" $1 | cut -f1 -d:)
  if [ -n $line ]
  then
    local replace=$(cat $3)
    echo "[INFO] Setting env $2=$replace in $1:${line}" >> $DOCK_INIT_LOG_PATH
    sed -i.bak "${line}s/env $2=.*/env $2=${replace}/" $1
  else
    echo "[ERROR] Could not find 'env $2' in $1"
  fi
}

source /opt/runnable/env
echo `date` "[INFO] environment:" `env` >> $DOCK_INIT_LOG_PATH

# Replace various service environment values for correct NODE_ENV
replace_env $DOCKER_LISTENER_CONF 'RABBITMQ_HOSTNAME' $RABBITMQ_HOSTNAME
replace_env $DOCKER_LISTENER_CONF 'RABBITMQ_PORT' $RABBITMQ_PORT_PATH
replace_env $DOCKER_LISTENER_CONF 'RABBITMQ_USERNAME' $RABBITMQ_USERNAME_PATH
replace_env $DOCKER_LISTENER_CONF 'RABBITMQ_PASSWORD' $RABBITMQ_PASSWORD_PATH
replace_env $DOCKER_LISTENER_CONF 'REDIS_IPADDRESS' $REDIS_IPADDRESS_PATH
replace_env $DOCKER_LISTENER_CONF 'REDIS_PORT' $REDIS_PORT_PATH
replace_env $SAURON_CONF 'REDIS_PORT' $REDIS_PORT_PATH
replace_env $SAURON_CONF 'REDIS_IPADDRESS' $REDIS_IPADDRESS_PATH

# Create cert (with exp backoff)
echo `date` "[INFO] Generating Host Certificate"
attempt=1
timeout=1
while true
do
  if [[ $DOCK_INIT_LOG_STDOUT == 1 ]]
  then
    bash $CERT_SCRIPT
  else
    bash $CERT_SCRIPT >> $DOCK_INIT_LOG_PATH
  fi

  if [[ $? == 0 ]]
  then
    break
  fi
  sleep $timeout
  attempt=$(( attempt + 1 ))
  timeout=$(( timeout * 2 ))
done

# Restart docker
service docker restart

# Upstart dock (with exp backoff)
attempt=1
timeout=1
while true
do
  if [[ $DOCK_INIT_LOG_STDOUT == 1 ]]
  then
    bash $UPSTART_SCRIPT
  else
    bash $UPSTART_SCRIPT >> $DOCK_INIT_LOG_PATH
  fi

  if [[ $? == 0 ]]
  then
    break
  fi
  sleep $timeout
  attempt=$(( attempt + 1 ))
  timeout=$(( timeout * 2 ))
done

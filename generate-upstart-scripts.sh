#!/bin/bash
set -e

echo `date` "[INFO] Configuring Upstart Scripts" >> $DOCK_INIT_LOG_PATH

SERVICE_TEMPLATE_DIR=$DOCK_INIT_BASE/consul-resources/templates/services

echo `date` "[TRACE] Configuring docker-listener" >> $DOCK_INIT_LOG_PATH
consul-template \
  -config=$DOCK_INIT_BASE/consul-resources/template-config.hcl \
  -once \
  -template=$SERVICE_TEMPLATE_DIR/docker-listener.conf.ctmpl:/etc/init/docker-listener.conf
echo manual > /etc/init/docker-listener.override

echo `date` "[TRACE] Configuring sauron" >> $DOCK_INIT_LOG_PATH
consul-template \
  -config=$DOCK_INIT_BASE/consul-resources/template-config.hcl \
  -once \
  -template=$SERVICE_TEMPLATE_DIR/sauron.conf.ctmpl:/etc/init/sauron.conf
echo manual > /etc/init/sauron.override

echo `date` "[TRACE] Configuring charon" >> $DOCK_INIT_LOG_PATH
consul-template \
  -config=$DOCK_INIT_BASE/consul-resources/template-config.hcl \
  -once \
  -template=$SERVICE_TEMPLATE_DIR/charon.conf.ctmpl:/etc/init/charon.conf
echo manual > /etc/init/charon.override

echo `date` "[TRACE] Done Generating Upstart Scripts" >> $DOCK_INIT_LOG_PATH

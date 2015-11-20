#!/bin/bash
set -e

echo `date` "[INFO] Configuring Upstart Scripts"

# get the logging to rollbar methods
. $DOCK_INIT_BASE/lib/rollbar.sh

SERVICE_TEMPLATE_DIR=$DOCK_INIT_BASE/consul-resources/templates/services

echo `date` "[TRACE] Configuring docker-listener"
trap 'report_err_to_rollbar "Consul-Template: Failed to Render docker-listener Config" "Consule-Template was unable to realize the given template."; exit 1' ERR
consul-template \
  -config=$DOCK_INIT_BASE/consul-resources/template-config.hcl \
  -once \
  -template=$SERVICE_TEMPLATE_DIR/docker-listener.conf.ctmpl:/etc/init/docker-listener.conf
echo manual > /etc/init/docker-listener.override
trap - ERR

echo `date` "[TRACE] Configuring sauron"
trap 'report_err_to_rollbar "Consul-Template: Failed to Render sauron Config" "Consule-Template was unable to realize the given template."; exit 1' ERR
consul-template \
  -config=$DOCK_INIT_BASE/consul-resources/template-config.hcl \
  -once \
  -template=$SERVICE_TEMPLATE_DIR/sauron.conf.ctmpl:/etc/init/sauron.conf
echo manual > /etc/init/sauron.override
trap - ERR

echo `date` "[TRACE] Configuring charon"
trap 'report_err_to_rollbar "Consul-Template: Failed to Render charon Config" "Consule-Template was unable to realize the given template."; exit 1' ERR
consul-template \
  -config=$DOCK_INIT_BASE/consul-resources/template-config.hcl \
  -once \
  -template=$SERVICE_TEMPLATE_DIR/charon.conf.ctmpl:/etc/init/charon.conf
echo manual > /etc/init/charon.override
trap - ERR

echo `date` "[TRACE] Done Generating Upstart Scripts"

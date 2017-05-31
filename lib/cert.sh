#!/bin/bash

# Methods for generating and removing docker host certs on the dock.

source "${DOCK_INIT_BASE}/lib/util/log.sh"
source "${DOCK_INIT_BASE}/lib/util/rollbar.sh"

CERT_PATH="/etc/ssl/docker"

if [ -z "${DOCKER_CERT_CA_BASE64+x}" ]; then
  log::fatal "DOCKER_CERT_CA_BASE64 is not defined"
  exit 1
else
  export DOCKER_CERT_CA_BASE64
fi

if [ -z "${DOCKER_CERT_CA_KEY_BASE64+x}" ]; then
  log::fatal "DOCKER_CERT_CA_KEY_BASE64 is not defined"
  exit 1
else
  export DOCKER_CERT_CA_KEY_BASE64
fi

if [ -z "${DOCKER_CERT_PASS+x}" ]; then
  log::fatal "DOCKER_CERT_PASS is not defined"
  exit 1
else
  export DOCKER_CERT_PASS
fi

# Generates the host certs for this dock
cert::generate() {
  if [ -z "${HOST_IP+x}" ]; then
    log::fatal "HOST_IP is not defined"
    exit 1
  else
    export HOST_IP
  fi

  mkdir -p ${CERT_PATH}
  echo ${DOCKER_CERT_CA_BASE64} | base64 --decode > ${CERT_PATH}/ca.pem
  echo ${DOCKER_CERT_CA_KEY_BASE64} | base64 --decode > ${CERT_PATH}/ca-key.pem
  echo ${DOCKER_CERT_PASS} | base64 --decode > ${CERT_PATH}/pass

  # generate server key
  openssl genrsa -out "$CERT_PATH/key.pem" 2048
  chmod 400 "$CERT_PATH/key.pem"

  # generate host CSR
  openssl req \
    -subj "/CN=$HOST_IP" \
    -new \
    -key "$CERT_PATH/key.pem" \
    -out "$CERT_PATH/server-$HOST_IP.csr"
  chmod 400 "$CERT_PATH/server-$HOST_IP.csr"

  # put host IP in alternate names
  echo "subjectAltName = IP:$HOST_IP,IP:127.0.0.1,DNS:localhost" > \
    "$CERT_PATH/extfile-$HOST_IP.cnf"

  # generate host certificate
  openssl x509 \
    -req \
    -days 365 \
    -in "$CERT_PATH/server-$HOST_IP.csr" \
    -CA $CERT_PATH/ca.pem \
    -CAkey $CERT_PATH/ca-key.pem \
    -CAcreateserial \
    -out "$CERT_PATH/cert.pem" \
    -extfile "$CERT_PATH/extfile-$HOST_IP.cnf" \
    -passin file:$CERT_PATH/pass
  chmod 400 "$CERT_PATH/cert.pem"

  # Explicitly return success
  return 0
}

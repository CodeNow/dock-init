#!/bin/bash

# Methods for generating and removing docker host certs on the dock.
# @author Anand Patel
# @author Ryan Sandor Richards
# @author Bryan Kendall

source "${DOCK_INIT_BASE}/lib/util/log.sh"
source "${DOCK_INIT_BASE}/lib/util/rollbar.sh"

CERT_PATH="/etc/ssl/docker"

# Remove any preloaded certs (from the original instance used to build the AMI)
cert::remove() {
  rm -f $CERT_PATH/cert.pem
  rm -f $CERT_PATH/key.pem
}

# Generates the host certs for this dock
cert::generate() {
  # Remove any left-over certs from the machine
  cert::remove

  # Require that we have the correct pems
  if [ ! -e $CERT_PATH/ca-key.pem ]; then
    log::fatal "Missing ca-key.pem"
    return 1
  fi

  if [ ! -e $CERT_PATH/ca.pem ]; then
    log::fatal "Missing ca.pem"
    return 1
  fi

  # generate server key
  openssl genrsa -out "$CERT_PATH/key.pem" 2048
  chmod 400 "$CERT_PATH/key.pem"

  # generate host CSR
  openssl req \
    -subj "/CN=$HOST_IP" \
    -new \
    -key "$CERT_PATH/key.pem" \
    -out "$CERT_PATH/server-$host.csr"
  chmod 400 "$CERT_PATH/server-$host.csr"

  # put host IP in alternate names
  echo "subjectAltName = IP:$host,IP:127.0.0.1,DNS:localhost" > \
    "$CERT_PATH/extfile-$host.cnf"

  # generate host certificate
  openssl x509 \
    -req \
    -days 365 \
    -in "$CERT_PATH/server-$host.csr" \
    -CA $CERT_PATH/ca.pem \
    -CAkey $CERT_PATH/ca-key.pem \
    -CAcreateserial \
    -out "$CERT_PATH/cert.pem" \
    -extfile "$CERT_PATH/extfile-$host.cnf" \
    -passin file:$CERT_PATH/pass
  chmod 400 "$CERT_PATH/cert.pem"

  # Explicitly return success
  return 0
}

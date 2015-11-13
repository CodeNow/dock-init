#!/bin/bash
set -e

HOST=`/sbin/ifconfig eth0 | grep "inet addr" | awk -F: '{print $2}' | awk '{print $1}'`
CERT_PATH=/etc/ssl/docker

# Remove any preloaded certs (from the original instance used to build the AMI)
rm -f $CERT_PATH/cert.pem
rm -f $CERT_PATH/key.pem

# Require that we have ca.pem and ca-key.pem
if [ ! -e $CERT_PATH/ca-key.pem ]; then
  echo `date` "[FATAL] Missing ca-key.pem"
  exit 1
fi

if [ ! -e $CERT_PATH/ca.pem ]; then
  echo `date` "[FATAL] Missing ca.pem"
  exit 1
fi

# generate server key
openssl genrsa -out "$CERT_PATH/key.pem" 2048
chmod 400 "$CERT_PATH/key.pem"

# generate host CSR
openssl req \
  -subj "/CN=$HOST" \
  -new \
  -key "$CERT_PATH/key.pem" \
  -out "$CERT_PATH/server-$HOST.csr"
chmod 400 "$CERT_PATH/server-$HOST.csr"

# put host IP in alternate names
echo "subjectAltName = IP:$HOST,IP:127.0.0.1,DNS:localhost" > "$CERT_PATH/extfile-$HOST.cnf"

# generate host certificate
openssl x509 \
  -req \
  -days 365 \
  -in "$CERT_PATH/server-$HOST.csr" \
  -CA $CERT_PATH/ca.pem \
  -CAkey $CERT_PATH/ca-key.pem \
  -CAcreateserial \
  -out "$CERT_PATH/cert.pem" \
  -extfile "$CERT_PATH/extfile-$HOST.cnf" \
  -passin file:$CERT_PATH/pass
chmod 400 "$CERT_PATH/cert.pem"

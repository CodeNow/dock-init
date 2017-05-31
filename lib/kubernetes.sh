#!/bin/bash

if [ -z "${K8_TOKEN+x}" ]; then
  log::fatal "K8_TOKEN is not defined"
  exit 1
else
  export K8_TOKEN
fi

if [ -z "${K8_HOST+x}" ]; then
  log::fatal "K8_HOST is not defined"
  exit 1
else
  export K8_HOST
fi

export NODE=`hostname -f`

# add orgid and github id labels to k8 nodes
k8::set_node_labels () {
  curl  -s \
        -k \
        -H "Authorization: Bearer $K8_TOKEN" \
        -H "Content-Type: application/strategic-merge-patch+json" \
        --request PATCH \
        -d @- \
        https://${K8_HOST}/api/v1/nodes/${NODE} <<EOF
{
  "metadata": {
    "labels": {
      "runnable.org.id": "${ORG_ID}",
      "runnable.org.githubid": "${POPPA_ID}"
    }
  }
}
EOF
}

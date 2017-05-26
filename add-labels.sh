#!/bin/sh
export NODE=`hostname -f`

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


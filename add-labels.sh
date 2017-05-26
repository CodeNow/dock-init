#!/bin/sh

export K8_TOKEN=eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJrdWJlcm5ldGVzL3NlcnZpY2VhY2NvdW50Iiwia3ViZXJuZXRlcy5pby9zZXJ2aWNlYWNjb3VudC9uYW1lc3BhY2UiOiJkZWZhdWx0Iiwia3ViZXJuZXRlcy5pby9zZXJ2aWNlYWNjb3VudC9zZWNyZXQubmFtZSI6ImRvY2tzLXRva2VuLXMxNjA1Iiwia3ViZXJuZXRlcy5pby9zZXJ2aWNlYWNjb3VudC9zZXJ2aWNlLWFjY291bnQubmFtZSI6ImRvY2tzIiwia3ViZXJuZXRlcy5pby9zZXJ2aWNlYWNjb3VudC9zZXJ2aWNlLWFjY291bnQudWlkIjoiNTQwNGQ2MmQtNDBlNy0xMWU3LTg2MDUtMDI4OGIwYzI2N2IwIiwic3ViIjoic3lzdGVtOnNlcnZpY2VhY2NvdW50OmRlZmF1bHQ6ZG9ja3MifQ.tXFk9UOoqGhfyC-mmLc1GvECS5HsqiAWWQAGn7Th7j-aaJER3X6Ai6YmHYhd7acVGj8DL3hngh-i5bQ0lNDpfVVQPTJQnwsKnwEH_QAjbBAWhQ3LPwK-F0hNQf18rr-swQXRG2WOeD2cAftvm--Jr5qddRQxx9cUHs9ZygHW8WnNKkzj3V0j_Uf2XYPEzcd7o0ZnYRYwzDVBJxs2eLxzymnCQQsgzosGiaYIWcERpqMUex6-oa4mua8BBEJ1zZdJrLS2APFQhdzFODh9eqKBGKZR_AgOgI_wARDnMGOh2nCU2LZbU1YWiqTJUcCE2B3fCnCK84Cl-MfX5Y61XNpG_Q
export K8_HOST=api.kubernetes-dock.runnable-gamma.com
export NODE=ip-10-4-132-158.us-west-2.compute.internal

export ORG_GITHUB_ID=1234

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
      "runnable.org.githubid": "${ORG_GITHUB_ID}"
    }
  }
}
EOF


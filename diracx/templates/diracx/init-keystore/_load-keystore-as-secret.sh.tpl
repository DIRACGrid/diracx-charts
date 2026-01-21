#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

namespace={{ .Release.Namespace }}

KEYSTORE_PATH=/keystore/jwks.json

if [[ ! -f $KEYSTORE_PATH ]]; then
  echo "Keystore is missing"
  exit 1;
fi

# Check if the keystore secret already exists
if kubectl -n "$namespace" get secret diracx-jwks >/dev/null 2>&1; then
  echo "diracx-jwks already present, skipping keystore generation"
  exit 0
fi

# Create the keystore secret
kubectl create secret generic diracx-jwks \
  --namespace=$namespace \
  --from-file=$KEYSTORE_PATH \

#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

KEYSTORE_PATH=/keystore/jwks.json

if [[ -f $KEYSTORE_PATH ]]; then
    echo "JWKS already exists, this is not supported!"
    exit 1
fi

# Generate the initial keystore
python -m diracx.logic rotate-jwk \
  --jwks-path $KEYSTORE_PATH

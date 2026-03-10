#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

python -m diracx.logic cleanup-authdb --db-url "${DIRACX_DB_URL_AUTHDB}"

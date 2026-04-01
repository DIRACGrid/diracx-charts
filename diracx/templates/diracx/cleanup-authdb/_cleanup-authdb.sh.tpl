#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

python -m diracx.logic cleanup-authdb

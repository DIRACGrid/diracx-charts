#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

python -c "from diracx.core.config import ConfigSource; ConfigSource.create().read_config()"

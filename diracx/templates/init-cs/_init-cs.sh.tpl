#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

CS_REPO=/cs_store/initialRepo

if [[ -d "${CS_REPO}" ]]; then
    echo "CS repo already exists, this is not supported!"
    exit 1
fi

dirac internal generate-cs /cs_store/initialRepo

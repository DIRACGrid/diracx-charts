#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

CS_REPO=/cs_store/initialRepo

if [[ -d "${CS_REPO}" ]]; then
    echo "CS repo already exists, this is not supported!"
    exit 1
fi

dirac internal generate-cs /cs_store/initialRepo \
    --vo=diracAdmin --user-group=admin \
    --idp-url={{ .Values.dex.config.issuer | quote }} \
{{- with (first .Values.dex.config.staticClients) }}
    --idp-client-id={{ .id | quote }}
{{- end }}

{{- range $user := index .Values "init-cs" "defaultUsers" }}
dirac internal add-user /cs_store/initialRepo \
    --vo={{ $user.vo | quote }} --user-group={{ $user.userGroup | quote }} \
    --sub={{ $user.sub | quote }} --preferred-username={{ $user.preferredUsername | quote }}
{{- end }}

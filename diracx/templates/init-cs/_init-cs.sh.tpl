#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

CS_REPO=/cs_store/initialRepo

if [[ -d "${CS_REPO}" ]]; then
    echo "CS repo already exists, this is not supported!"
    exit 1
fi

dirac internal generate-cs /cs_store/initialRepo

{{- range $vo := index .Values "init-cs" "defaultVOs" }}
dirac internal add-vo /cs_store/initialRepo \
    --vo={{ $vo.name | quote }} \
    --idp-url={{ $vo.idp_url | quote }} \
    --idp-client-id={{ $vo.idp_client_id | quote }}
{{- end }}

{{- range $group := index .Values "init-cs" "defaultGroups" }}
dirac internal add-group /cs_store/initialRepo \
    --vo={{ $group.vo | quote }} \
    --group={{ $group.name | quote }}
{{- end }}

{{- range $user := index .Values "init-cs" "defaultUsers" }}
dirac internal add-user /cs_store/initialRepo \
    --vo={{ $user.vo | quote }} \
    --user-group={{ $user.userGroup | quote }} \
    --sub={{ $user.sub | quote }} \
    --preferred-username={{ $user.preferredUsername | quote }}
{{- end }}

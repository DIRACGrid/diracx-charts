#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

CS_REPO=/cs_store/initialRepo

if [[ -d "${CS_REPO}" ]]; then
    echo "CS repo already exists, this is not supported!"
    exit 1
fi

dirac internal generate-cs /cs_store/initialRepo

{{- range $vo := index .Values "init-cs" "VOs" }}

dirac internal add-vo /cs_store/initialRepo \
    --vo={{ $vo.name | quote }} \
    --idp-url={{ $vo.IdP.idp_url | quote }} \
    --idp-client-id={{ $vo.IdP.idp_client_id | quote }} \
{{- with $vo.defaultGroup }}
    --default-group={{ . | quote }}
{{- end }}

{{- with $vo.Groups }}
{{- range $group := $vo.Groups }}
dirac internal add-group /cs_store/initialRepo \
    --vo={{ $vo.name | quote }} \
    --group={{ $group.name | quote }}
{{- end }}
{{- end }}

{{- with $vo.Users }}
{{- range $user := $vo.Users }}
dirac internal add-user /cs_store/initialRepo \
    --vo={{ $vo.name | quote }} \
    --sub={{ $user.sub | quote }} \
    --preferred-username={{ $user.preferredUsername | quote }} \
{{- range $usergroup := $user.groups }}
    --group={{ $usergroup | quote }} \
{{- end }}

{{- end }}
{{- end }}
{{- end }}

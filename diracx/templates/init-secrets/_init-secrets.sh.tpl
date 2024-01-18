#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

namespace={{ .Release.Namespace }}
release={{ .Release.Name }}

pushd $(mktemp -d)

# Args pattern, length
function gen_random(){
  head -c 4096 /dev/urandom | LC_CTYPE=C tr -cd $1 | head -c $2
}

# Args: secretname, args
function generate_secret_if_needed(){
  local secret_args=( "${@:2}")
  local secret_name=$1

  if ! $(kubectl --namespace=$namespace get secret $secret_name > /dev/null 2>&1); then
    kubectl --namespace=$namespace create secret generic $secret_name ${secret_args[@]}
  else
    echo "secret \"$secret_name\" already exists."

    for arg in "${secret_args[@]}"; do
      local from=$(echo -n ${arg} | cut -d '=' -f1)

      if [ -z "${from##*literal*}" ]; then
        local key=$(echo -n ${arg} | cut -d '=' -f2)
        local desiredValue=$(echo -n ${arg} | cut -d '=' -f3-)
        local flags=(
          "--namespace=$namespace"
          "--allow-missing-template-keys=false"
        )

        if ! $(kubectl "${flags[@]}" get secret $secret_name -ojsonpath="{.data.${key}}" > /dev/null 2>&1); then
          echo "key \"${key}\" does not exist. patching it in."

          if [ "${desiredValue}" != "" ]; then
            desiredValue=$(echo -n "${desiredValue}" | base64 -w 0)
          fi

          kubectl --namespace=$namespace patch secret ${secret_name} -p "{\"data\":{\"$key\":\"${desiredValue}\"}}"
        fi
      fi
    done
  fi
}

# Generate the token signing key
ssh-keygen -P '' -trsa -b4096 -mPEM -f"$PWD/rsa256.key"
generate_secret_if_needed diracx-token-signing-key --from-file "$PWD/rsa256.key"

{{- if .Values.rabbitmq.enabled }}
# Generate the secrets for rabbitmq
generate_secret_if_needed {{ .Values.rabbitmq.auth.existingPasswordSecret }} --from-literal=rabbitmq-password=$(gen_random 'a-zA-Z0-9' 32)
generate_secret_if_needed {{ .Values.rabbitmq.auth.existingErlangSecret }} --from-literal=rabbitmq-erlang-cookie=$(gen_random 'a-zA-Z0-9' 32)
{{- end }}

# If we deploy MySQL ourselves
{{- if .Values.mysql.enabled }}

# Make sure that there are no default connection settings
{{ if .Values.diracx.sqlDbs.default }}
{{ fail "There should be no default connection settings if running mysql from this Chart" }}
{{ end }}

# Generate the secrets for mysql
generate_secret_if_needed {{ .Values.mysql.auth.existingSecret }} --from-literal=mysql-root-password=$(gen_random 'a-zA-Z0-9' 32)
generate_secret_if_needed {{ .Values.mysql.auth.existingSecret }} --from-literal=mysql-replication-password=$(gen_random 'a-zA-Z0-9' 32)
generate_secret_if_needed {{ .Values.mysql.auth.existingSecret }} --from-literal=mysql-password=$(gen_random 'a-zA-Z0-9' 32)

# Make secrets for the sqlalchemy connection urls
mysql_password=$(kubectl get secret {{ .Values.mysql.auth.existingSecret }} -ojsonpath="{.data.mysql-password}" | base64 -d)
mysql_root_password=$(kubectl get secret {{ .Values.mysql.auth.existingSecret }} -ojsonpath="{.data.mysql-root-password}" | base64 -d)

{{- range $dbName,$dbSettings := .Values.diracx.sqlDbs.dbs }}


# Make sure there are no connection settings
{{ if $dbSettings }}
{{ fail "There should be no connection settings if running mysql from this Chart" }}
{{ end }}

generate_secret_if_needed diracx-sql-connection-urls \
  --from-literal=DIRACX_DB_URL_{{ $dbName | upper }}="mysql+aiomysql://{{ $.Values.mysql.auth.username }}:${mysql_password}@{{ $.Release.Name }}-mysql:3306/{{ $dbName }}"
generate_secret_if_needed diracx-sql-root-connection-urls \
  --from-literal=DIRACX_DB_URL_{{ $dbName | upper }}="mysql+aiomysql://root:${mysql_root_password}@{{ $.Release.Name }}-mysql:3306/{{ $dbName }}"
{{- end }}

# If we use an external MySQL instance
{{- else }}


{{- $default_db_host := $.Values.diracx.sqlDbs.default.host }}
{{- $default_db_root_user := $.Values.diracx.sqlDbs.default.rootUser }}
{{- $default_db_root_password := $.Values.diracx.sqlDbs.default.rootPassword }}
{{- $default_db_user := $.Values.diracx.sqlDbs.default.user }}
{{- $default_db_password := $.Values.diracx.sqlDbs.default.password }}

{{- range $db_name, $db_settings := .Values.diracx.sqlDbs.dbs }}


{{- if kindIs "map" $db_settings }}
{{- $db_host :=  $db_settings.host | default $default_db_host  }}
{{- $db_root_user :=  $db_settings.rootUser | default $default_db_root_user  }}
{{- $db_root_password :=  $db_settings.rootPassword | default $default_db_root_password  }}
{{- $db_user := $db_settings.user | default $default_db_user }}
{{- $db_password :=  $db_settings.password | default $default_db_password  }}
generate_secret_if_needed diracx-sql-connection-urls \
  --from-literal=DIRACX_DB_URL_{{ $db_name | upper }}="mysql+aiomysql://{{ $db_user }}:{{ $db_password }}@{{ $db_host }}/{{ $db_name }}"
generate_secret_if_needed diracx-sql-root-connection-urls \
  --from-literal=DIRACX_DB_URL_{{ $db_name | upper }}="mysql+aiomysql://{{ $db_root_user }}:{{ $db_root_password }}@{{ $db_host }}/{{ $db_name }}"
{{- else }}
generate_secret_if_needed diracx-sql-connection-urls \
  --from-literal=DIRACX_DB_URL_{{ $db_name | upper }}="mysql+aiomysql://{{ $default_db_user }}:{{ $default_db_password }}@{{ $default_db_host }}/{{ $db_name }}"
generate_secret_if_needed diracx-sql-root-connection-urls \
  --from-literal=DIRACX_DB_URL_{{ $db_name | upper }}="mysql+aiomysql://{{ $default_db_root_user }}:{{ $default_db_root_password }}@{{ $default_db_host }}/{{ $db_name }}"
{{- end }}

{{- end }}
{{- end }}

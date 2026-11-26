#!/usr/bin/env bash
set -x
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

# Generate the token state key (to safely pass information between authorize/device requests)
generate_secret_if_needed diracx-dynamic-secrets --from-literal=DIRACX_SERVICE_AUTH_STATE_KEY=$(head -c 32 /dev/urandom | base64)

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


# Allow an internal database name, but no connection overrides
{{- $settings := default dict $dbSettings }}
{{ if omit $settings "internalName" }}
{{ fail "There should be no connection settings if running mysql from this Chart" }}
{{ end }}
{{- $schemaPath := $settings.internalName | default $dbName | urlquery | replace "+" "%20" }}

generate_secret_if_needed diracx-sql-connection-urls \
  --from-literal=DIRACX_DB_URL_{{ $dbName | upper }}="mysql+aiomysql://{{ $.Values.mysql.auth.username }}:${mysql_password}@{{ $.Release.Name }}-mysql:3306/{{ $schemaPath }}"
generate_secret_if_needed diracx-sql-root-connection-urls \
  --from-literal=DIRACX_DB_URL_{{ $dbName | upper }}="mysql+aiomysql://root:${mysql_root_password}@{{ $.Release.Name }}-mysql:3306/{{ $schemaPath }}"
{{- end }}

# If we use an external MySQL instance
{{- else }}
{{- range $dbName, $dbSettings := .Values.diracx.sqlDbs.dbs }}
{{- $connection := include "diracx.externalDatabaseConnection" (dict "backend" "MySQL" "section" "sqlDbs" "name" $dbName "shared" $.Values.diracx.sqlDbs.default "overrides" $dbSettings) | fromYaml }}
{{- $schemaName := $dbName }}
{{- if eq $dbName "AuthDB" }}
{{- $schemaName = "DiracXAuthDB" }}
{{- end }}
{{- $schemaName = $connection.internalName | default $schemaName }}
{{- $url := urlJoin (dict "scheme" "mysql+aiomysql" "userinfo" (print $connection.user ":" $connection.password) "host" $connection.host "path" $schemaName) }}
{{- $rootUrl := urlJoin (dict "scheme" "mysql+aiomysql" "userinfo" (print $connection.rootUser ":" $connection.rootPassword) "host" $connection.host "path" $schemaName) }}

generate_secret_if_needed diracx-sql-connection-urls \
  --from-literal=DIRACX_DB_URL_{{ $dbName | upper }}="{{ $url }}"
generate_secret_if_needed diracx-sql-root-connection-urls \
  --from-literal=DIRACX_DB_URL_{{ $dbName | upper }}="{{ $rootUrl }}"
{{- end }}
{{- end }}

{{- if .Values.taskWorkers.enabled }}
# Generate the Redis URL secret for the task broker
{{- if .Values.redisTasks.enabled }}
generate_secret_if_needed diracx-task-redis-url \
  --from-literal=DIRACX_TASKS_REDIS_URL="redis://{{ include "diracx.taskRedisName" . }}:{{ .Values.redisTasks.port }}"
{{- else if .Values.diracx.tasks.redis_url }}
generate_secret_if_needed diracx-task-redis-url \
  --from-literal=DIRACX_TASKS_REDIS_URL="{{ .Values.diracx.tasks.redis_url }}"
{{- else }}
{{ fail "diracx.tasks.redis_url must be set when redisTasks.enabled is false and taskWorkers.enabled is true" }}
{{- end }}
{{- end }}

# If we deploy opensearch ourselves
{{- if .Values.opensearch.enabled }}

# Make sure that there are no default connection settings
{{ if .Values.diracx.osDbs.default }}
{{ fail "There should be no default connection settings if running OpenSearch from this Chart" }}
{{ end }}

{{- range $osDbName,$osDbSettings := .Values.diracx.osDbs.dbs }}


# Make sure there are no connection settings
{{ if $osDbSettings }}
{{ fail "There should be no connection settings if running OpenSearch from this Chart" }}
{{ end }}

generate_secret_if_needed diracx-os-connection-urls \
  --from-literal=DIRACX_OS_DB_{{ $osDbName | upper }}='{"hosts": "admin:admin@opensearch-cluster-master:9200", "use_ssl": true, "verify_certs": false}'
generate_secret_if_needed diracx-os-root-connection-urls \
  --from-literal=DIRACX_OS_DB_{{ $osDbName | upper }}='{"hosts": "admin:admin@opensearch-cluster-master:9200", "use_ssl": true, "verify_certs": false}'
{{- end }}

# If we use an external OpenSearch instance
{{- else }}
{{- range $osDbName, $osDbSettings := .Values.diracx.osDbs.dbs }}
{{- $connection := include "diracx.externalDatabaseConnection" (dict "backend" "OpenSearch" "section" "osDbs" "name" $osDbName "shared" $.Values.diracx.osDbs.default "overrides" $osDbSettings) | fromYaml }}
generate_secret_if_needed diracx-os-connection-urls \
  --from-literal=DIRACX_OS_DB_{{ $osDbName | upper }}='{"hosts": "{{ $connection.user }}:{{ $connection.password }}@{{ $connection.host }}", "use_ssl": true, "verify_certs": false}'
generate_secret_if_needed diracx-os-root-connection-urls \
  --from-literal=DIRACX_OS_DB_{{ $osDbName | upper }}='{"hosts": "{{ $connection.rootUser }}:{{ $connection.rootPassword }}@{{ $connection.host }}", "use_ssl": true, "verify_certs": false}'
{{- end }}
{{- end }}

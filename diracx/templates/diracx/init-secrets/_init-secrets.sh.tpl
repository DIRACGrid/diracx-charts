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
{{- $default_db_port := $.Values.diracx.sqlDbs.default.port | default 3306 }}
{{- $default_db_root_user := $.Values.diracx.sqlDbs.default.rootUser }}
{{- $default_db_root_password := $.Values.diracx.sqlDbs.default.rootPassword }}
{{- $default_db_user := $.Values.diracx.sqlDbs.default.user }}
{{- $default_db_password := $.Values.diracx.sqlDbs.default.password }}

{{- range $dbName, $db_settings := .Values.diracx.sqlDbs.dbs }}

{{- $db_host := $default_db_host }}
{{- $db_port := $default_db_port }}
{{- $db_root_user := $default_db_root_user }}
{{- $db_root_password := $default_db_root_password }}
{{- $db_user := $default_db_user }}
{{- $db_password := $default_db_password }}
{{- $db_internal_name := $dbName }}

{{- if kindIs "map" $db_settings }}
  {{- $db_host = $db_settings.host | default $default_db_host }}
  {{- $db_port = $db_settings.port | default $default_db_port }}
  {{- $db_root_user = $db_settings.rootUser | default $default_db_root_user }}
  {{- $db_root_password = $db_settings.rootPassword | default $default_db_root_password }}
  {{- $db_user = $db_settings.user | default $default_db_user }}
  {{- $db_password = $db_settings.password | default $default_db_password }}
  {{- $db_internal_name = $db_settings.internalName | default $dbName }}
{{- end }}

{{- $db_host_port := $db_host }}
{{- if and $db_port (not (regexMatch ":[0-9]+$" $db_host)) }}
  {{- $db_host_port = print $db_host ":" $db_port }}
{{- end }}

{{- $sql_url := printf "mysql+aiomysql://%s:%s@%s/%s" ($db_user | urlquery) ($db_password | urlquery) $db_host_port $db_internal_name }}
{{- $sql_root_url := printf "mysql+aiomysql://%s:%s@%s/%s" ($db_root_user | urlquery) ($db_root_password | urlquery) $db_host_port $db_internal_name }}

generate_secret_if_needed diracx-sql-connection-urls \
  {{ printf "--from-literal=DIRACX_DB_URL_%s=%s" ($dbName | upper) $sql_url | replace "'" "'\\''" | squote }}
generate_secret_if_needed diracx-sql-root-connection-urls \
  {{ printf "--from-literal=DIRACX_DB_URL_%s=%s" ($dbName | upper) $sql_root_url | replace "'" "'\\''" | squote }}

{{- end }}
{{- end }}

### OpenSearch settings

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
{{ fail "There should be no default connection settings if running opensearch from this Chart" }}
{{ end }}

{{- range $osDbName,$osDbSettings := .Values.diracx.osDbs.dbs }}

# Make sure there are no connection settings
{{ if $osDbSettings }}
{{ fail "There should be no connection settings if running opensearch from this Chart" }}
{{ end }}

{{- $os_url_string := urlJoin (dict "scheme" "https" "userinfo" "admin:admin" "host" "opensearch-cluster-master:9200" ) }}

generate_secret_if_needed diracx-os-connection-urls \
  --from-literal=DIRACX_OS_DB_{{ $osDbName | upper }}='{"hosts": "{{ $os_url_string }}", "use_ssl": true, "verify_certs": false}'
generate_secret_if_needed diracx-os-root-connection-urls \
  --from-literal=DIRACX_OS_DB_{{ $osDbName | upper }}='{"hosts": "{{ $os_url_string }}", "use_ssl": true, "verify_certs": false}'
{{- end }}

# If we use an external OpenSearch instance
{{- else }}

{{- $defaultOsDbHost := $.Values.diracx.osDbs.default.host }}
{{- $defaultOsDbPort := $.Values.diracx.osDbs.default.port | default 9200 }}
{{- $defaultOsDbRootUser := $.Values.diracx.osDbs.default.rootUser }}
{{- $defaultOsDbRootPassword := $.Values.diracx.osDbs.default.rootPassword }}
{{- $defaultOsDbUser := $.Values.diracx.osDbs.default.user }}
{{- $defaultOsDbPassword := $.Values.diracx.osDbs.default.password }}

{{- range $osDbName, $osDbSettings := .Values.diracx.osDbs.dbs }}

{{- $osDbHost := $defaultOsDbHost }}
{{- $osDbPort := $defaultOsDbPort }}
{{- $osDbRootUser := $defaultOsDbRootUser }}
{{- $osDbRootPassword := $defaultOsDbRootPassword }}
{{- $osDbUser := $defaultOsDbUser }}
{{- $osDbPassword := $defaultOsDbPassword }}

{{- if kindIs "map" $osDbSettings }}
  {{- $osDbHost = $osDbSettings.host | default $defaultOsDbHost }}
  {{- $osDbPort = $osDbSettings.port | default $defaultOsDbPort }}
  {{- $osDbRootUser = $osDbSettings.rootUser | default $defaultOsDbRootUser }}
  {{- $osDbRootPassword = $osDbSettings.rootPassword | default $defaultOsDbRootPassword }}
  {{- $osDbUser = $osDbSettings.user | default $defaultOsDbUser }}
  {{- $osDbPassword = $osDbSettings.password | default $defaultOsDbPassword }}
{{- end }}

{{- $os_host_port := $osDbHost }}
{{- if and $osDbPort (not (regexMatch ":[0-9]+$" $osDbHost)) }}
  {{- $os_host_port = print $osDbHost ":" $osDbPort }}
{{- end }}

{{- $os_url_string := printf "https://%s:%s@%s" ($osDbUser | urlquery) ($osDbPassword | urlquery) $os_host_port }}
{{- $os_root_url_string := printf "https://%s:%s@%s" ($osDbRootUser | urlquery) ($osDbRootPassword | urlquery) $os_host_port }}

{{- $os_json := printf "{\"hosts\": \"%s\", \"use_ssl\": true, \"verify_certs\": false}" $os_url_string }}
{{- $os_root_json := printf "{\"hosts\": \"%s\", \"use_ssl\": true, \"verify_certs\": false}" $os_root_url_string }}

generate_secret_if_needed diracx-os-connection-urls \
  {{ printf "--from-literal=DIRACX_OS_DB_%s=%s" ($osDbName | upper) $os_json | replace "'" "'\\''" | squote }}
generate_secret_if_needed diracx-os-root-connection-urls \
  {{ printf "--from-literal=DIRACX_OS_DB_%s=%s" ($osDbName | upper) $os_root_json | replace "'" "'\\''" | squote }}

{{- end }}
{{- end }}

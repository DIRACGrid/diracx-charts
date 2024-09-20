#!/usr/bin/env bash
set -x
set -euo pipefail
IFS=$'\n\t'

namespace={{ .Release.Namespace }}
release={{ .Release.Name }}
connStart=""

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

# Args database_instance
function set_sql_connection_driver(){
  case $1 in
    "MySQL")
      connStart="mysql+aiomysql"
      ;;
    "PostgreSQL")
      connStart="postgresql+asyncpg"
      ;;
    *)
      # Throw some kind of error
      echo "SQL Database \"" $1 "\" unknown" 1>&2
      exit 1
      ;;
  esac
}

# Generate the token signing key
ssh-keygen -P '' -trsa -b4096 -mPEM -f"$PWD/rsa256.key"
generate_secret_if_needed diracx-token-signing-key --from-file "$PWD/rsa256.key"

# Generate the token state key (to safely pass information between authorize/device requests)
generate_secret_if_needed diracx-dynamic-secrets --from-literal=DIRACX_SERVICE_AUTH_STATE_KEY=$(head -c 32 /dev/urandom | base64)

{{- if .Values.rabbitmq.enabled }}
# Generate the secrets for rabbitmq
generate_secret_if_needed {{ .Values.rabbitmq.auth.existingPasswordSecret }} --from-literal=rabbitmq-password=$(gen_random 'a-zA-Z0-9' 32)
generate_secret_if_needed {{ .Values.rabbitmq.auth.existingErlangSecret }} --from-literal=rabbitmq-erlang-cookie=$(gen_random 'a-zA-Z0-9' 32)
{{- end }}

{{- $externalDB := false }}

# If we deploy MySQL ourselves
{{- if .Values.mysql.enabled }}

  # Make sure that there are no default connection settings
  {{ if .Values.diracx.sqlDbs.default }}
    {{ fail "There should be no default connection settings if running mysql from this Chart" }}
  {{ end }}

  # Get the start of the connection string of MySQL (db+driver)
  set_sql_connection_driver "MySQL"

  # Generate the secrets for MySQL
  generate_secret_if_needed {{ .Values.mysql.auth.existingSecret }} --from-literal=mysql-root-password=$(gen_random 'a-zA-Z0-9' 32)
  generate_secret_if_needed {{ .Values.mysql.auth.existingSecret }} --from-literal=mysql-replication-password=$(gen_random 'a-zA-Z0-9' 32)
  generate_secret_if_needed {{ .Values.mysql.auth.existingSecret }} --from-literal=mysql-password=$(gen_random 'a-zA-Z0-9' 32)

  # Set the values for the sqlalchemy connection urls
  user={{ $.Values.mysql.auth.username }}
  root_user="root"
  password=$(kubectl get secret {{ .Values.mysql.auth.existingSecret }} -ojsonpath="{.data.mysql-password}" | base64 -d)
  root_password=$(kubectl get secret {{ .Values.mysql.auth.existingSecret }} -ojsonpath="{.data.mysql-root-password}" | base64 -d)
  host={{ $.Release.Name }}-mysql:3306

# If we deploy PostgreSQL ourselves
{{- else if .Values.postgresql.enabled }}

  # Make sure that there are no default connection settings
  {{ if .Values.diracx.sqlDbs.default }}
    {{ fail "There should be no default connection settings if running PostgreSQL from this Chart" }}
  {{ end }}

  # Get the start of the connection string of PostgreSQL (db+driver)
  set_sql_connection_driver "PostgreSQL"

  # Generate the secrets for PostgreSQL
  generate_secret_if_needed {{ .Values.postgresql.auth.existingSecret }} --from-literal=postgres-password=$(gen_random 'a-zA-Z0-9' 32)
  #generate_secret_if_needed {{ .Values.postgresql.auth.existingSecret }} --from-literal=postgresql-replication-password=$(gen_random 'a-zA-Z0-9' 32)
  generate_secret_if_needed {{ .Values.postgresql.auth.existingSecret }} --from-literal=password=$(gen_random 'a-zA-Z0-9' 32)

  # Set the values for the sqlalchemy connection urls
  user={{ $.Values.postgresql.auth.username }}
  root_user="postgres"
  password=$(kubectl get secret {{ .Values.postgresql.auth.existingSecret }} -ojsonpath="{.data.password}" | base64 -d)
  root_password=$(kubectl get secret {{ .Values.postgresql.auth.existingSecret }} -ojsonpath="{.data.postgres-password}" | base64 -d)
  host={{ $.Release.Name }}-postgresql:5432

# If we use an external DB instance
{{- else }}

  {{- $externalDB = true }}

  set_sql_connection_driver {{ .Values.diracx.sqlDbs.default.type }}

  # Set the default values
  user={{ $.Values.diracx.sqlDbs.default.user }}
  root_user={{ $.Values.diracx.sqlDbs.default.rootUser }}
  password={{ $.Values.diracx.sqlDbs.default.password }}
  root_password={{ $.Values.diracx.sqlDbs.default.rootPassword }}
  host={{ $.Values.diracx.sqlDbs.default.host }}

{{- end }}

# Configure the Connections
{{- range $dbName, $dbSettings := .Values.diracx.sqlDbs.dbs }}
  # If is not an external db and has settings
  {{ if and (not $externalDB) $dbSettings }}
    {{ fail "There should be no connection settings if running a local database from this Chart" }}
  {{ end }}

  db_connStart=$connStart   # Configurable at database level?

  {{- if kindIs "map" $dbSettings }}
    db_user={{ $dbSettings.user | default $.Values.diracx.sqlDbs.default.user }}
    db_root_user={{ $dbSettings.rootUser | default $.Values.diracx.sqlDbs.default.rootUser }}
    db_password={{ $dbSettings.password | default $.Values.diracx.sqlDbs.default.password }}
    db_root_password={{ $dbSettings.rootPassword | default $.Values.diracx.sqlDbs.default.rootPassword }}
    db_host={{ $dbSettings.host | default $.Values.diracx.sqlDbs.default.host }}
    db_name={{ $dbSettings.internalName | default $dbName }}
  {{- else }}
    db_user=$user
    db_root_user=$root_user
    db_password=$password
    db_root_password=$root_password
    db_host=$host
    db_name={{ $dbName }}
  {{- end }}

  # User connection string
  generate_secret_if_needed diracx-sql-connection-urls \
    --from-literal=DIRACX_DB_URL_{{ $dbName | upper }}="${db_connStart}://${db_user}:${db_password}@${db_host}/${db_name}"

  # Root connection string
  generate_secret_if_needed diracx-sql-root-connection-urls \
    --from-literal=DIRACX_DB_URL_{{ $dbName | upper }}="${db_connStart}://${db_root_user}:${db_root_password}@${db_host}/${db_name}"

{{- end }}















{{- if .Values.initOs.enabled }}
# If we deploy opensearch ourselves
{{- if .Values.opensearch.enabled }}

# Make sure that there are no default connection settings
{{ if .Values.diracx.osDbs.default }}
{{ fail "There should be no default connection settings if running mysql from this Chart" }}
{{ end }}

{{- range $osDbName,$osDbSettings := .Values.diracx.osDbs.dbs }}


# Make sure there are no connection settings
{{ if $osDbSettings }}
{{ fail "There should be no connection settings if running mysql from this Chart" }}
{{ end }}

generate_secret_if_needed diracx-os-connection-urls \
  --from-literal=DIRACX_OS_DB_{{ $osDbName | upper }}='{"hosts": "admin:admin@opensearch-cluster-master:9200", "use_ssl": true, "verify_certs": false}'
generate_secret_if_needed diracx-os-root-connection-urls \
  --from-literal=DIRACX_OS_DB_{{ $osDbName | upper }}='{"hosts": "admin:admin@opensearch-cluster-master:9200", "use_ssl": true, "verify_certs": false}'
{{- end }}

# If we use an external MySQL instance
{{- else }}


{{- $defaultOsDbHost := $.Values.diracx.osDbs.default.host }}
{{- $defaultOsDbRootUser := $.Values.diracx.osDbs.default.rootUser }}
{{- $defaultOsDbRootPassword := $.Values.diracx.osDbs.default.rootPassword }}
{{- $defaultOsDbUser := $.Values.diracx.osDbs.default.user }}
{{- $defaultOsDbPassword := $.Values.diracx.osDbs.default.password }}

{{- range $osDbName, $osDbSettings := .Values.diracx.osDbs.dbs }}


{{- if kindIs "map" $osDbSettings }}
{{- $osDbHost :=  $osDbSettings.host | default $defaultOsDbHost  }}
{{- $osDbRootUser :=  $osDbSettings.rootUser | default $defaultOsDbRootUser  }}
{{- $osDbRootPassword :=  $osDbSettings.rootPassword | default $defaultOsDbRootPassword  }}
{{- $osDbUser := $osDbSettings.user | default $defaultOsDbUser }}
{{- $osDbPassword :=  $osDbSettings.password | default $defaultOsDbPassword  }}
generate_secret_if_needed diracx-os-connection-urls \
  --from-literal=DIRACX_OS_DB_{{ $osDbName | upper }}='{"hosts": "{{ $osDbUser }}:{{ $osDbPassword }}@{{ $osDbHost }}", "use_ssl": true, "verify_certs": false}'
generate_secret_if_needed diracx-os-root-connection-urls \
  --from-literal=DIRACX_OS_DB_{{ $osDbName | upper }}='{"hosts": "{{ $osDbRootUser }}:{{ $osDbRootPassword }}@{{ $osDbHost }}", "use_ssl": true, "verify_certs": false}'
{{- else }}
generate_secret_if_needed diracx-os-connection-urls \
  --from-literal=DIRACX_OS_DB_{{ $osDbName | upper }}='{"hosts": "{{ $defaultOsDbUser }}:{{ $defaultOsDbPassword }}@{{ $defaultOsDbHost }}", "use_ssl": true, "verify_certs": false}'
generate_secret_if_needed diracx-os-root-connection-urls \
  --from-literal=DIRACX_OS_DB_{{ $osDbName | upper }}='{"hosts": "{{ $defaultOsDbRootUser }}:{{ $defaultOsDbRootPassword }}@{{ $defaultOsDbHost }}", "use_ssl": true, "verify_certs": false}'
{{- end }}

{{- end }}
{{- end }}
{{- end }}

{{/*
Expand the name of the chart.
*/}}
{{- define "diracx.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "diracx.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "diracx.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "diracx.labels" -}}
helm.sh/chart: {{ include "diracx.chart" . }}
{{ include "diracx.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "diracx.selectorLabels" -}}
app.kubernetes.io/name: {{ include "diracx.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}
{{- define "diracxWeb.selectorLabels" -}}
app.kubernetes.io/name: {{ include "diracx.name" . }}-web
app.kubernetes.io/instance: {{ .Release.Name }}-web
{{- end }}
{{- define "diracxCli.selectorLabels" -}}
app.kubernetes.io/name: {{ include "diracx.name" . }}-cli
app.kubernetes.io/instance: {{ .Release.Name }}-cli
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "diracx.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "diracx.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Return the fullname template for the initCs job.
*/}}
{{- define "initCs.fullname" -}}
{{- printf "%s-init-cs" .Release.Name -}}
{{- end -}}

{{/*
Create a default fully qualified job name for initCs.
Due to the job only being allowed to run once, we add the chart revision so helm
upgrades don't cause errors trying to create the already ran job.
Due to the helm delete not cleaning up these jobs, we add a random value to
reduce collisions.
*/}}
{{- define "initCs.jobname" -}}
{{- $name := include "initCs.fullname" . | trunc 55 | trimSuffix "-" -}}
{{- $rand := randAlphaNum 3 | lower }}
{{- printf "%s-%d-%s" $name .Release.Revision $rand | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Return the fullname template for the initSecrets job.
*/}}
{{- define "initSecrets.fullname" -}}
{{- printf "%s-init-secrets" .Release.Name -}}
{{- end -}}

{{/*
Return the name template for shared-secrets job.
*/}}
{{- define "initSecrets.name" -}}
{{- $sharedSecretValues := index .Values "initSecrets" -}}
{{- default "init-secrets" $sharedSecretValues.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create a default fully qualified job name for initSecrets.
Due to the job only being allowed to run once, we add the chart revision so helm
upgrades don't cause errors trying to create the already ran job.
Due to the helm delete not cleaning up these jobs, we add a random value to
reduce collisions.
*/}}
{{- define "initSecrets.jobname" -}}
{{- $name := include "initSecrets.fullname" . | trunc 55 | trimSuffix "-" -}}
{{- $rand := randAlphaNum 3 | lower }}
{{- printf "%s-%d-%s" $name .Release.Revision $rand | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create the name of the service account to use for initSecrets job
*/}}
{{- define "initSecrets.serviceAccountName" -}}
{{- $initSecretsValues := index .Values "initSecrets" -}}
{{- if $initSecretsValues.serviceAccount.create -}}
    {{ default (include "initSecrets.fullname" .) $initSecretsValues.serviceAccount.name }}
{{- else -}}
    {{ coalesce $initSecretsValues.serviceAccount.name .Values.global.serviceAccount.name "default" }}
{{- end -}}
{{- end -}}

{{/*
Return the fullname template for the initSql job.
*/}}
{{- define "initSql.fullname" -}}
{{- printf "%s-init-sql" .Release.Name -}}
{{- end -}}

{{/*
Create a default fully qualified job name for initSql.
Due to the job only being allowed to run once, we add the chart revision so helm
upgrades don't cause errors trying to create the already ran job.
Due to the helm delete not cleaning up these jobs, we add a random value to
reduce collisions.
*/}}
{{- define "initSql.jobname" -}}
{{- $name := include "initSql.fullname" . | trunc 55 | trimSuffix "-" -}}
{{- $rand := randAlphaNum 3 | lower }}
{{- printf "%s-%d-%s" $name .Release.Revision $rand | trunc 63 | trimSuffix "-" -}}
{{- end -}}


{{/*
Return the fullname template for the initOs job.
*/}}
{{- define "initOs.fullname" -}}
{{- printf "%s-init-os" .Release.Name -}}
{{- end -}}

{{/*
Create a default fully qualified job name for initOs.
Due to the job only being allowed to run once, we add the chart revision so helm
upgrades don't cause errors trying to create the already ran job.
Due to the helm delete not cleaning up these jobs, we add a random value to
reduce collisions.
*/}}
{{- define "initOs.jobname" -}}
{{- $name := include "initOs.fullname" . | trunc 55 | trimSuffix "-" -}}
{{- $rand := randAlphaNum 3 | lower }}
{{- printf "%s-%d-%s" $name .Release.Revision $rand | trunc 63 | trimSuffix "-" -}}
{{- end -}}

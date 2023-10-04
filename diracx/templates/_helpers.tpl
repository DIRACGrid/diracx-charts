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
Return the fullname template for the init-cs job.
*/}}
{{- define "init-cs.fullname" -}}
{{- printf "%s-init-cs" .Release.Name -}}
{{- end -}}

{{/*
Create a default fully qualified job name for init-cs.
Due to the job only being allowed to run once, we add the chart revision so helm
upgrades don't cause errors trying to create the already ran job.
Due to the helm delete not cleaning up these jobs, we add a random value to
reduce collisions.
*/}}
{{- define "init-cs.jobname" -}}
{{- $name := include "init-cs.fullname" . | trunc 55 | trimSuffix "-" -}}
{{- $rand := randAlphaNum 3 | lower }}
{{- printf "%s-%d-%s" $name .Release.Revision $rand | trunc 63 | trimSuffix "-" -}}
{{- end -}}


{{/*
Return the fullname template for the init-secrets job.
*/}}
{{- define "init-secrets.fullname" -}}
{{- printf "%s-init-secrets" .Release.Name -}}
{{- end -}}

{{/*
Return the name template for shared-secrets job.
*/}}
{{- define "init-secrets.name" -}}
{{- $sharedSecretValues := index .Values "init-secrets" -}}
{{- default "init-secrets" $sharedSecretValues.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create a default fully qualified job name for init-secrets.
Due to the job only being allowed to run once, we add the chart revision so helm
upgrades don't cause errors trying to create the already ran job.
Due to the helm delete not cleaning up these jobs, we add a random value to
reduce collisions.
*/}}
{{- define "init-secrets.jobname" -}}
{{- $name := include "init-secrets.fullname" . | trunc 55 | trimSuffix "-" -}}
{{- $rand := randAlphaNum 3 | lower }}
{{- printf "%s-%d-%s" $name .Release.Revision $rand | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create the name of the service account to use for init-secrets job
*/}}
{{- define "init-secrets.serviceAccountName" -}}
{{- $initSecretsValues := index .Values "init-secrets" -}}
{{- if $initSecretsValues.serviceAccount.create -}}
    {{ default (include "init-secrets.fullname" .) $initSecretsValues.serviceAccount.name }}
{{- else -}}
    {{ coalesce $initSecretsValues.serviceAccount.name .Values.global.serviceAccount.name "default" }}
{{- end -}}
{{- end -}}

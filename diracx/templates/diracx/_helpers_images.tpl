
{{/*
Generates the full image path for a given image name and registry type.

If registryType is not specified it defaults to "ghcr".
For each registryType, it looks for a corresponding registry URL in the global images values, e.g. ghcr_registry for "ghcr".

Repository is required and specifies the image repository name. If registry is not specified, only repository:tag is returned.
Beware that repository should not contain the registry part if registry is specified.

If tag, is not specified, it is taken from global images tag, defaulting to Chart.AppVersion if not set.

Can be used as follows:

{{ include "diracx.image" (dict "registryType" "ghcr" "repository" "services" "root" . ) }}

Or

{{ include "diracx.image" (dict "repository" "client" "root" . ) }}

to produce an image path as:

ghcr.io/diracgrid/diracx/services:v0.0.7

*/}}
{{- define "diracx.image" }}
{{- $root := .root }}
{{- $registry := index $root.Values.global.images (printf "%s_registry" ( .registryType | default "ghcr" )) }}
{{- $repository := .repository }}
{{- if not $repository -}}
{{- fail (printf "Non-empty repository is required when calling diracx.image") -}}
{{- end -}}
{{- $tag := .tag | default $root.Values.global.images.tag | default $root.Chart.AppVersion }}
{{- if $registry -}}
{{- $registry }}/{{ $repository }}:{{ $tag }}
{{- else -}}
{{- $repository }}:{{ $tag }}
{{- end -}}
{{- end }}

{{/*
Generates the busybox image path
*/}}
{{- define "diracx.busyboxImage" }}
{{- include "diracx.image" (dict "registryType" .Values.global.images.busybox.registryType "repository" .Values.global.images.busybox.repository "root" . "tag" .Values.global.images.busybox.tag ) }}
{{- end }}

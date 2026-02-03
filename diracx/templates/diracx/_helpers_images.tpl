
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
The following are helper functions to generate image paths for specific diracx images. These images are reused in multiple places.

TODO: is it right that some of them use "latest" tag while others use the global tag or chart app version?
*/}}


{{/*
Generates the diracx base image path
*/}}

{{- define "diracx.baseImage" }}
{{- include "diracx.image" (dict "repository" .Values.global.images.diracx_base_image "root" .  ) }}
{{- end }}


{{/*
Generates the services image path
*/}}
{{- define "diracx.servicesImage" }}
{{- include "diracx.image" (dict "repository" .Values.global.images.services "root" .  ) }}
{{- end }}


{{/*
Generates the client image path
*/}}
{{- define "diracx.clientImage" }}
{{- include "diracx.image" (dict "repository" .Values.global.images.client "root" .  ) }}
{{- end }}


{{/*
Generates the secret generation image path
*/}}
{{- define "diracx.secretGenerationImage" }}
{{- include "diracx.image" (dict "repository" .Values.global.images.secret_generation "root" . "tag" "latest" ) }}
{{- end }}

{{/*
Generates the busybox image path
*/}}
{{- define "diracx.busyboxImage" }}
{{- include "diracx.image" (dict "registryType" .Values.global.images.busybox.registryType "repository" .Values.global.images.busybox.repository "root" . "tag" .Values.global.images.busybox.tag ) }}
{{- end }}

{{/*
Generates the web image path
*/}}
{{- define "diracx.webImage" }}
{{- include "diracx.image" (dict "registryType" .Values.global.images.web.registryType "repository" .Values.global.images.web.repository "root" . "tag" .Values.global.images.web.tag ) }}
{{- end }}

# {{ .Values.developer.nodeImage }}

{{/*
Generates the node image path
*/}}
{{- define "diracx.nodeImage" }}
{{- include "diracx.image" (dict "registryType" "dockerhub" "repository" .Values.developer.nodeImage "root" . "tag" "latest" ) }}
{{- end }}

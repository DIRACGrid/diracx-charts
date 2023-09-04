# diracx

![Version: 0.1.0](https://img.shields.io/badge/Version-0.1.0-informational?style=flat-square) ![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square) ![AppVersion: 0.0.1a](https://img.shields.io/badge/AppVersion-0.0.1a-informational?style=flat-square)

A Helm chart for deploying DiracX

## Requirements

| Repository | Name | Version |
|------------|------|---------|
| https://charts.dexidp.io/ | dex | 0.14.2 |
| https://charts.min.io/ | minio | 5.0.11 |
| https://opensearch-project.github.io/helm-charts/ | opensearch | 2.13.1 |

## Values

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| affinity | object | `{}` |  |
| autoscaling.enabled | bool | `false` |  |
| autoscaling.maxReplicas | int | `100` |  |
| autoscaling.minReplicas | int | `1` |  |
| autoscaling.targetCPUUtilizationPercentage | int | `80` |  |
| developer.diracxInstallationPath | string | `"/opt/conda/lib/python3.11/site-packages/diracx"` |  |
| developer.diracxSourcePath | string | `"/diracx_source/"` |  |
| developer.enabled | bool | `true` |  |
| dex."https.enabled" | bool | `false` |  |
| dex.config.enablePasswordDB | bool | `true` |  |
| dex.config.expiry.authRequests | string | `"24h"` |  |
| dex.config.expiry.deviceRequests | string | `"5m"` |  |
| dex.config.expiry.idTokens | string | `"24h"` |  |
| dex.config.expiry.signingKeys | string | `"6h"` |  |
| dex.config.issuer | string | `"http://anything:32002"` |  |
| dex.config.logger.format | string | `"text"` |  |
| dex.config.logger.level | string | `"debug"` |  |
| dex.config.oauth2.alwaysShowLoginScreen | bool | `false` |  |
| dex.config.oauth2.responseTypes[0] | string | `"code"` |  |
| dex.config.oauth2.skipApprovalScreen | bool | `false` |  |
| dex.config.staticClients | list | `[]` |  |
| dex.config.staticPasswords | list | `[]` |  |
| dex.config.storage.config.file | string | `"/tmp/dex.db"` |  |
| dex.config.storage.type | string | `"sqlite3"` |  |
| dex.config.web.http | int | `8000` |  |
| dex.enabled | bool | `true` |  |
| dex.ingress.enabled | bool | `false` |  |
| dex.service.ports.http.nodePort | int | `32002` |  |
| dex.service.ports.http.port | int | `8000` |  |
| dex.service.type | string | `"NodePort"` |  |
| diracx.csVolumeName | string | `"pv-cs-store"` |  |
| diracx.settings.DIRACX_CONFIG_BACKEND_URL | string | `"git+file:///cs_store/initialRepo"` |  |
| diracx.settings.DIRACX_DB_URL_AUTHDB | string | `"sqlite+aiosqlite:///:memory:"` |  |
| diracx.settings.DIRACX_DB_URL_JOBDB | string | `"sqlite+aiosqlite:///:memory:"` |  |
| diracx.settings.DIRACX_SERVICE_AUTH_ALLOWED_REDIRECTS | string | `"[\"http://anything:8000/docs/oauth2-redirect\"]"` |  |
| diracx.settings.DIRACX_SERVICE_AUTH_TOKEN_KEY | string | `"file:///signing-key/rs256.key"` |  |
| fullnameOverride | string | `""` |  |
| image.pullPolicy | string | `"IfNotPresent"` |  |
| image.repository | string | `"ghcr.io/diracgrid/diracx/server"` |  |
| image.tag | string | `"latest"` |  |
| ingress.annotations."nginx.ingress.kubernetes.io/use-regex" | string | `"true"` |  |
| ingress.className | string | `"nginx"` |  |
| ingress.enabled | bool | `true` |  |
| ingress.hosts[0].paths[0].backend.service.name | string | `"diracx-demo"` |  |
| ingress.hosts[0].paths[0].backend.service.port.number | int | `8000` |  |
| ingress.hosts[0].paths[0].path | string | `"/"` |  |
| ingress.hosts[0].paths[0].pathType | string | `"Prefix"` |  |
| ingress.tls | list | `[]` |  |
| minio.consoleIngress.enabled | bool | `false` |  |
| minio.consoleService.type | string | `"NodePort"` |  |
| minio.enabled | bool | `true` |  |
| minio.environment.MINIO_BROWSER_REDIRECT_URL | string | `"http://anything:32001/"` |  |
| minio.ingress.enabled | bool | `false` |  |
| minio.mode | string | `"standalone"` |  |
| minio.persistence.enabled | bool | `false` |  |
| minio.replicas | int | `1` |  |
| minio.resources.requests.memory | string | `"512Mi"` |  |
| minio.rootPassword | string | `"rootpass123"` |  |
| minio.rootUser | string | `"rootuser"` |  |
| minio.service.type | string | `"NodePort"` |  |
| nameOverride | string | `""` | type=kubernetes.io/dockerconfigjson imagePullSecrets:   - name: regcred |
| nodeSelector | object | `{}` |  |
| opensearch.config."cluster.routing.allocation.disk.threshold_enabled" | string | `"true"` |  |
| opensearch.config."cluster.routing.allocation.disk.watermark.flood_stage" | string | `"200mb"` |  |
| opensearch.config."cluster.routing.allocation.disk.watermark.high" | string | `"300mb"` |  |
| opensearch.config."cluster.routing.allocation.disk.watermark.low" | string | `"500mb"` |  |
| opensearch.config."plugins.security.disabled" | string | `"true"` |  |
| opensearch.enabled | bool | `true` |  |
| opensearch.opensearchJavaOpts | string | `"-Xms256m -Xmx256m"` |  |
| opensearch.singleNode | bool | `true` |  |
| podAnnotations | object | `{}` |  |
| podSecurityContext | object | `{}` |  |
| replicaCount | int | `1` |  |
| resources | object | `{}` |  |
| securityContext | object | `{}` |  |
| service.port | int | `8000` |  |
| service.type | string | `"ClusterIP"` |  |
| serviceAccount.annotations | object | `{}` |  |
| serviceAccount.create | bool | `true` |  |
| serviceAccount.name | string | `""` |  |
| tolerations | list | `[]` |  |

----------------------------------------------
Autogenerated from chart metadata using [helm-docs v1.11.0](https://github.com/norwoodj/helm-docs/releases/v1.11.0)

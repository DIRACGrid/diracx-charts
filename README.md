# Helm chart for DiracX

This helm chart is intended to be used in two ways:

 * Development: The ./run_demo.sh script allows the infrastructure to be ran locally with docker+kind
 * Production: TODO

![Version: 0.1.0](https://img.shields.io/badge/Version-0.1.0-informational?style=flat-square) ![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square) ![AppVersion: 0.0.1a](https://img.shields.io/badge/AppVersion-0.0.1a-informational?style=flat-square)

## Running locally

TODO

### Interacting with the demo

#### Kubernetes basics

Assuming you have exported the environment variables printed by the demo script you can interact with the demo cluster using:

```bash
# List the running pods
kubectl get pods
# Get some more information about a pod
kubectl describe pod/<pod name>
# Show the logs of a running pod
kubectl logs <pod name>
# Show the logs of a running pod and keep following them
kubectl logs -f <pod name>
# Run a command in one of the non-LbAPI pods
kubectl exec -it <pod name> -- /bin/bash
# Run a command in one of the LbAPI pods with the conda environment loaded
kubectl exec -it <pod name> -- /dockerMicroMambaEntrypoint.sh bash
```

#### Helm basics

When running the demo some an `values.yaml` file is created as `.demo/values.yaml`.
This file can be used with helm to interact with the running demo to make changes to what is running in the cluster.

```bash
# Show what will be changed by running "helm upgrade"
helm diff upgrade diracx-demo ./diracx --values .demo/values.yaml
# Actually run "helm upgrade" to apply changes
helm upgrade diracx-demo ./diracx --values .demo/values.yaml
```

## Deploying a custom branch to DIRAC certification

Apply the following on top of the standard `values.yaml` file, replacing `USERNAME` and `BRANCH_NAME` with the appropriate values.

```yaml
global:
  images:
    tag: "dev"
    # TODO: We should use the base images here but pythonModulesToInstall would need to be split
    services: ghcr.io/diracgrid/diracx/services
    client: ghcr.io/diracgrid/diracx/client

diracx:
  pythonModulesToInstall:
    - "git+https://github.com/USERNAME/diracx.git@BRANCH_NAME#egg=diracx_core&subdirectory=diracx-core"
    - "git+https://github.com/USERNAME/diracx.git@BRANCH_NAME#egg=diracx_db&subdirectory=diracx-db"
    - "git+https://github.com/USERNAME/diracx.git@BRANCH_NAME#egg=diracx_routers&subdirectory=diracx-routers"yaml
```

## Deploying in production

TODO

## Requirements

| Repository | Name | Version |
|------------|------|---------|
|  | cert-manager-issuer | *.*.* |
| https://charts.bitnami.com/bitnami/ | mysql | 9.11.0 |
| https://charts.bitnami.com/bitnami/ | rabbitmq | 12.0.10 |
| https://charts.dexidp.io/ | dex | 0.14.2 |
| https://charts.jetstack.io | cert-manager | 1.13.1 |
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
| cert-manager-issuer.enabled | bool | `true` |  |
| cert-manager.enabled | bool | `true` |  |
| cert-manager.installCRDs | bool | `true` |  |
| developer.autoReload | bool | `true` |  |
| developer.editableMountedPythonModules | bool | `true` |  |
| developer.enableCoverage | bool | `false` |  |
| developer.enabled | bool | `true` |  |
| developer.ipAlias | string | `nil` |  |
| developer.localCSPath | string | `"/local_cs_store"` |  |
| developer.mountedPythonModulesToInstall | list | `[]` |  |
| developer.nodeImage | string | `"node:16-alpine"` |  |
| developer.nodeModuleToInstall | string | `nil` |  |
| developer.offline | bool | `false` |  |
| developer.sourcePath | string | `"/diracx_source"` |  |
| developer.urls | object | `{}` |  |
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
| diracx.manageOSIndices | bool | `true` |  |
| diracx.mysqlDatabases[0] | string | `"AuthDB"` |  |
| diracx.mysqlDatabases[1] | string | `"JobDB"` |  |
| diracx.mysqlDatabases[2] | string | `"JobLoggingDB"` |  |
| diracx.mysqlDatabases[3] | string | `"SandboxMetadataDB"` |  |
| diracx.mysqlDatabases[4] | string | `"TaskQueueDB"` |  |
| diracx.osDatabases[0] | string | `"JobParametersDB"` |  |
| diracx.pythonModulesToInstall | list | `[]` |  |
| diracx.service.port | int | `8000` |  |
| diracx.service.type | string | `"ClusterIP"` |  |
| diracx.settings.DIRACX_CONFIG_BACKEND_URL | string | `"git+file:///cs_store/initialRepo"` |  |
| diracx.settings.DIRACX_SERVICE_AUTH_ALLOWED_REDIRECTS | string | `"[\"http://anything:8000/docs/oauth2-redirect\"]"` |  |
| diracx.settings.DIRACX_SERVICE_AUTH_TOKEN_KEY | string | `"file:///signing-key/rsa256.key"` |  |
| diracxWeb.service.port | int | `8080` |  |
| diracxWeb.service.type | string | `"ClusterIP"` |  |
| fullnameOverride | string | `""` |  |
| global.activeDeadlineSeconds | int | `900` |  |
| global.batchJobTTL | int | `600` |  |
| global.imagePullPolicy | string | `"Always"` |  |
| global.images.client | string | `"ghcr.io/diracgrid/diracx/client"` |  |
| global.images.services | string | `"ghcr.io/diracgrid/diracx/services"` |  |
| global.images.tag | string | `"dev"` |  |
| global.images.web.repository | string | `"ghcr.io/diracgrid/diracx-web/static"` |  |
| global.images.web.tag | string | `"latest"` |  |
| ingress.annotations | object | `{}` |  |
| ingress.className | string | `"nginx"` |  |
| ingress.enabled | bool | `true` |  |
| ingress.tlsSecretName | string | `"myingress-cert"` |  |
| init-cs.defaultUsers | list | `[]` |  |
| init-cs.enabled | bool | `true` |  |
| init-secrets.enabled | bool | `true` |  |
| init-secrets.rbac.create | bool | `true` |  |
| init-secrets.serviceAccount.create | bool | `true` |  |
| init-secrets.serviceAccount.enabled | bool | `true` |  |
| init-secrets.serviceAccount.name | string | `nil` |  |
| init-sql.enabled | bool | `true` |  |
| init-sql.env | object | `{}` |  |
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
| mysql.auth.createDatabase | bool | `false` |  |
| mysql.auth.existingSecret | string | `"mysql-secret"` |  |
| mysql.auth.username | string | `"sqldiracx"` |  |
| mysql.enabled | bool | `true` |  |
| mysql.initdbScriptsConfigMap | string | `"mysql-init-diracx-dbs"` |  |
| nameOverride | string | `""` | type=kubernetes.io/dockerconfigjson imagePullSecrets:   - name: regcred |
| nodeSelector | object | `{}` |  |
| opensearch.config."opensearch.yml" | string | `"cluster.name: opensearch-cluster\n\n# Bind to all interfaces because we don't know what IP address Docker will assign to us.\nnetwork.host: 0.0.0.0\n\n# Setting network.host to a non-loopback address enables the annoying bootstrap checks. \"Single-node\" mode disables them again.\n# Implicitly done if \".singleNode\" is set to \"true\".\n# discovery.type: single-node\n\n# Start OpenSearch Security Demo Configuration\n# WARNING: revise all the lines below before you go into production\nplugins:\n  security:\n    ssl:\n      transport:\n        pemcert_filepath: esnode.pem\n        pemkey_filepath: esnode-key.pem\n        pemtrustedcas_filepath: root-ca.pem\n        enforce_hostname_verification: false\n      http:\n        enabled: true\n        pemcert_filepath: esnode.pem\n        pemkey_filepath: esnode-key.pem\n        pemtrustedcas_filepath: root-ca.pem\n    allow_unsafe_democertificates: true\n    allow_default_init_securityindex: true\n    authcz:\n      admin_dn:\n        - CN=kirk,OU=client,O=client,L=test,C=de\n    audit.type: internal_opensearch\n    enable_snapshot_restore_privilege: true\n    check_snapshot_restore_write_privileges: true\n    restapi:\n      roles_enabled: [\"all_access\", \"security_rest_api_access\"]\n    system_indices:\n      enabled: true\n      indices:\n        [\n          \".opendistro-alerting-config\",\n          \".opendistro-alerting-alert*\",\n          \".opendistro-anomaly-results*\",\n          \".opendistro-anomaly-detector*\",\n          \".opendistro-anomaly-checkpoints\",\n          \".opendistro-anomaly-detection-state\",\n          \".opendistro-reports-*\",\n          \".opendistro-notifications-*\",\n          \".opendistro-notebooks\",\n          \".opendistro-asynchronous-search-response*\",\n        ]\n######## End OpenSearch Security Demo Configuration ########\ncluster:\n  routing:\n    allocation:\n      disk:\n        threshold_enabled: \"true\"\n        watermark:\n          flood_stage: 200mb\n          low: 500mb\n          high: 300mb\n"` |  |
| opensearch.enabled | bool | `true` |  |
| opensearch.opensearchJavaOpts | string | `"-Xms256m -Xmx256m"` |  |
| opensearch.resources.requests.cpu | string | `"100m"` |  |
| opensearch.resources.requests.memory | string | `"100Mi"` |  |
| opensearch.singleNode | bool | `true` |  |
| podAnnotations | object | `{}` |  |
| podSecurityContext | object | `{}` |  |
| rabbitmq.auth.existingErlangSecret | string | `"rabbitmq-secret"` |  |
| rabbitmq.auth.existingPasswordSecret | string | `"rabbitmq-secret"` |  |
| rabbitmq.containerSecurityContext.enabled | bool | `false` |  |
| rabbitmq.enabled | bool | `true` |  |
| rabbitmq.podSecurityContext.enabled | bool | `false` |  |
| replicaCount | int | `1` |  |
| resources | object | `{}` |  |
| securityContext | object | `{}` |  |
| serviceAccount.annotations | object | `{}` |  |
| serviceAccount.create | bool | `true` |  |
| serviceAccount.name | string | `""` |  |
| tolerations | list | `[]` |  |

----------------------------------------------
Autogenerated from chart metadata using [helm-docs v1.11.2](https://github.com/norwoodj/helm-docs/releases/v1.11.2)

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
| https://grafana.github.io/helm-charts | grafana | 6.59.4 |
| https://helm.elastic.co | elasticsearch | 8.5.1 |
| https://jaegertracing.github.io/helm-charts | jaeger | 0.71.14 |
| https://open-telemetry.github.io/opentelemetry-helm-charts | opentelemetry-collector | 0.68.0 |
| https://opensearch-project.github.io/helm-charts/ | opensearch | 2.13.1 |
| https://prometheus-community.github.io/helm-charts | prometheus | 25.0.0 |

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
| developer.enableCoverage | bool | `false` |  |
| developer.enabled | bool | `true` |  |
| developer.ipAlias | string | `nil` |  |
| developer.localCSPath | string | `"/local_cs_store"` |  |
| developer.nodeImage | string | `"node:16-alpine"` |  |
| developer.nodeModuleToInstall | string | `nil` |  |
| developer.offline | bool | `false` |  |
| developer.pythonModulesToEditableInstall | list | `[]` |  |
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
| diracx.settings.DIRACX_LEGACY_EXCHANGE_HASHED_API_KEY | string | `"07cddf6948d316ac9d186544dc3120c4c6697d8f994619665985c0a5bf76265a"` |  |
| diracx.settings.DIRACX_SERVICE_AUTH_ALLOWED_REDIRECTS | string | `"[\"http://anything:8000/docs/oauth2-redirect\"]"` |  |
| diracx.settings.DIRACX_SERVICE_AUTH_TOKEN_KEY | string | `"file:///signing-key/rsa256.key"` |  |
| diracxWeb.image.repository | string | `"ghcr.io/diracgrid/diracx-web/static"` |  |
| diracxWeb.image.tag | string | `"latest"` |  |
| diracxWeb.service.port | int | `8080` |  |
| diracxWeb.service.type | string | `"ClusterIP"` |  |
| diracx.settings.DIRACX_SERVICE_AUTH_TOKEN_KEY | string | `"file:///signing-key/rs256.key"` |  |
| elasticsearch.enabled | bool | `true` |  |
| elasticsearch.esJavaOpts | string | `"-Xms128m -Xmx128m"` |  |
| elasticsearch.replicas | int | `1` |  |
| elasticsearch.resources.limits.cpu | string | `"1000m"` |  |
| elasticsearch.resources.limits.memory | string | `"512M"` |  |
| elasticsearch.resources.requests.cpu | string | `"100m"` |  |
| elasticsearch.resources.requests.memory | string | `"512M"` |  |
| elasticsearch.secret.password | string | `"elastic"` |  |
| elasticsearch.volumeClaimTemplate.accessModes[0] | string | `"ReadWriteOnce"` |  |
| elasticsearch.volumeClaimTemplate.resources.requests.storage | string | `"100M"` |  |
| elasticsearch.volumeClaimTemplate.storageClassName | string | `"standard"` |  |
| fullnameOverride | string | `""` |  |
| global.activeDeadlineSeconds | int | `900` |  |
| global.batchJobTTL | int | `600` |  |
| global.imagePullPolicy | string | `"Always"` |  |
| grafana.datasources."datasources.yaml".apiVersion | int | `1` |  |
| grafana.datasources."datasources.yaml".datasources[0].name | string | `"Jaeger"` |  |
| grafana.datasources."datasources.yaml".datasources[0].type | string | `"jaeger"` |  |
| grafana.datasources."datasources.yaml".datasources[0].url | string | `"http://diracx-demo-jaeger-query:16686"` |  |
| grafana.datasources."datasources.yaml".datasources[1].name | string | `"Prometheus"` |  |
| grafana.datasources."datasources.yaml".datasources[1].type | string | `"prometheus"` |  |
| grafana.datasources."datasources.yaml".datasources[1].url | string | `"http://diracx-demo-prometheus-server:80"` |  |
| grafana.datasources."datasources.yaml".datasources[2].basicAuth | bool | `true` |  |
| grafana.datasources."datasources.yaml".datasources[2].basicAuthUser | string | `"elastic"` |  |
| grafana.datasources."datasources.yaml".datasources[2].database | string | `"diracx_otel_logs_index"` |  |
| grafana.datasources."datasources.yaml".datasources[2].isDefault | bool | `false` |  |
| grafana.datasources."datasources.yaml".datasources[2].jsonData.esVersion | string | `"8.5.1"` |  |
| grafana.datasources."datasources.yaml".datasources[2].jsonData.logMessageField | string | `"full_message"` |  |
| grafana.datasources."datasources.yaml".datasources[2].jsonData.maxConcurrentShardRequests | int | `10` |  |
| grafana.datasources."datasources.yaml".datasources[2].jsonData.timeField | string | `"@timestamp"` |  |
| grafana.datasources."datasources.yaml".datasources[2].jsonData.timeout | int | `300` |  |
| grafana.datasources."datasources.yaml".datasources[2].jsonData.tlsSkipVerify | bool | `true` |  |
| grafana.datasources."datasources.yaml".datasources[2].name | string | `"Elasticsearch"` |  |
| grafana.datasources."datasources.yaml".datasources[2].secureJsonData.basicAuthPassword | string | `"elastic"` |  |
| grafana.datasources."datasources.yaml".datasources[2].type | string | `"elasticsearch"` |  |
| grafana.datasources."datasources.yaml".datasources[2].url | string | `"https://elasticsearch-master:9200"` |  |
| grafana.enabled | bool | `true` |  |
| grafana.service.nodePort | int | `32004` |  |
| grafana.service.port | int | `32004` |  |
| grafana.service.type | string | `"NodePort"` |  |
| image.pullPolicy | string | `"IfNotPresent"` |  |
| image.repository | string | `"ghcr.io/diracgrid/diracx/server"` |  |
| image.tag | string | `"latest"` |  |
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
| ingress.hosts[0].paths[0].backend.service.name | string | `"diracx-demo"` |  |
| ingress.hosts[0].paths[0].backend.service.port.number | int | `8000` |  |
| ingress.hosts[0].paths[0].path | string | `"/"` |  |
| ingress.hosts[0].paths[0].pathType | string | `"Prefix"` |  |
| ingress.tls | list | `[]` |  |
| jaeger.agent.enabled | bool | `false` |  |
| jaeger.allInOne.enabled | bool | `true` |  |
| jaeger.collector.enabled | bool | `false` |  |
| jaeger.enabled | bool | `true` |  |
| jaeger.provisionDataStore.cassandra | bool | `false` |  |
| jaeger.query.enabled | bool | `false` |  |
| jaeger.storage.type | string | `"none"` |  |
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
| opentelemetry-collector.config.exporters.elasticsearch/log.endpoints[0] | string | `"https://elastic:elastic@elasticsearch-master:9200"` |  |
| opentelemetry-collector.config.exporters.elasticsearch/log.logs_index | string | `"diracx_otel_logs_index"` |  |
| opentelemetry-collector.config.exporters.elasticsearch/log.sending_queue.enabled | bool | `true` |  |
| opentelemetry-collector.config.exporters.elasticsearch/log.sending_queue.num_consumers | int | `20` |  |
| opentelemetry-collector.config.exporters.elasticsearch/log.sending_queue.queue_size | int | `1000` |  |
| opentelemetry-collector.config.exporters.elasticsearch/log.tls.insecure_skip_verify | bool | `true` |  |
| opentelemetry-collector.config.exporters.logging.loglevel | string | `"debug"` |  |
| opentelemetry-collector.config.exporters.otlp/jaeger.endpoint | string | `"diracx-demo-jaeger-collector:4317"` |  |
| opentelemetry-collector.config.exporters.otlp/jaeger.tls.insecure | bool | `true` |  |
| opentelemetry-collector.config.exporters.prometheus.endpoint | string | `":8889"` |  |
| opentelemetry-collector.config.exporters.prometheus.metric_expiration | string | `"180m"` |  |
| opentelemetry-collector.config.exporters.prometheus.send_timestamps | bool | `true` |  |
| opentelemetry-collector.config.receivers.jaeger | string | `nil` |  |
| opentelemetry-collector.config.receivers.prometheus | string | `nil` |  |
| opentelemetry-collector.config.service.pipelines.logs.exporters[0] | string | `"elasticsearch/log"` |  |
| opentelemetry-collector.config.service.pipelines.logs.exporters[1] | string | `"logging"` |  |
| opentelemetry-collector.config.service.pipelines.metrics.exporters[0] | string | `"logging"` |  |
| opentelemetry-collector.config.service.pipelines.metrics.exporters[1] | string | `"prometheus"` |  |
| opentelemetry-collector.config.service.pipelines.traces.exporters[0] | string | `"otlp/jaeger"` |  |
| opentelemetry-collector.config.service.pipelines.traces.exporters[1] | string | `"logging"` |  |
| opentelemetry-collector.enabled | bool | `true` |  |
| opentelemetry-collector.mode | string | `"deployment"` |  |
| opentelemetry-collector.ports.promexp.containerPort | int | `8889` |  |
| opentelemetry-collector.ports.promexp.enabled | bool | `true` |  |
| opentelemetry-collector.ports.promexp.hostPort | int | `8889` |  |
| opentelemetry-collector.ports.promexp.protocol | string | `"TCP"` |  |
| opentelemetry-collector.ports.promexp.servicePort | int | `8889` |  |
| opentelemetry-collector.presets.kubeletMetrics.enabled | bool | `false` |  |
| opentelemetry-collector.presets.kubernetesAttributes.enabled | bool | `false` |  |
| opentelemetry-collector.presets.logsCollection.enabled | bool | `true` |  |
| podAnnotations | object | `{}` |  |
| podSecurityContext | object | `{}` |  |
| rabbitmq.auth.existingErlangSecret | string | `"rabbitmq-secret"` |  |
| rabbitmq.auth.existingPasswordSecret | string | `"rabbitmq-secret"` |  |
| prometheus.alertmanager.enabled | bool | `false` |  |
| prometheus.enabled | bool | `true` |  |
| prometheus.kube-state-metrics.enabled | bool | `false` |  |
| prometheus.prometheus-node-exporter.enabled | bool | `false` |  |
| prometheus.server.persistentVolume.enabled | bool | `false` |  |
| prometheus.serverFiles."prometheus.yml".scrape_configs[0].job_name | string | `"otel"` |  |
| prometheus.serverFiles."prometheus.yml".scrape_configs[0].scrape_interval | string | `"10s"` |  |
| prometheus.serverFiles."prometheus.yml".scrape_configs[0].static_configs[0].targets[0] | string | `"diracx-demo-opentelemetry-collector:8889"` |  |
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

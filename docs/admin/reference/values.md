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
| cert-manager-issuer.enabled | bool | `true` |  |
| cert-manager.enabled | bool | `true` |  |
| cert-manager.installCRDs | bool | `true` |  |
| developer.autoReload | bool | `true` | Enable automatic reloading inside uvicorn when the sources change Used by the integration tests for running closer to prod setup |
| developer.editableMountedPythonModules | bool | `true` | Use pip install -e for mountedPythonModulesToInstall This is used by the integration tests because editable install might behave differently |
| developer.enableCoverage | bool | `false` | Enable collection of coverage reports (intended for CI usage only) |
| developer.enabled | bool | `false` |  |
| developer.ipAlias | string | `nil` | The IP that the demo is running at |
| developer.localCSPath | string | `"/local_cs_store"` | If set, mount the CS stored localy instead of initializing a default one |
| developer.mountedNodeModuleToInstall | string | `nil` | Node module to install |
| developer.mountedPythonModulesToInstall | list | `[]` | List of packages which are mounted into developer.sourcePath and should be installed with pip install SOURCEPATH/... |
| developer.nodeImage | string | `"node:alpine"` | Image to use for the webapp if nodeModuleToInstall is set |
| developer.nodeWorkspacesDirectories | list | `[]` | List of node workspace directories to manage in the diracx-web container (node_modules) |
| developer.offline | bool | `false` | Make it possible to launch the demo without having an internet connection |
| developer.sourcePath | string | `"/diracx_source"` | Path from which to mount source of DIRACX |
| developer.urls | object | `{}` | URLs which can be used to access various components of the demo (diracx, minio, dex, etc). They are used by the diracx tests |
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
| dex.image.tag | string | `"v2.41.1"` |  |
| dex.ingress.enabled | bool | `false` |  |
| dex.service.ports.http.nodePort | int | `32002` |  |
| dex.service.ports.http.port | int | `8000` |  |
| dex.service.type | string | `"NodePort"` |  |
| diracx.hostname | string | `""` | Required: The hostname where the webapp/API is running |
| diracx.osDbs.dbs | string | `nil` | Which DiracX OpenSearch DBs are used? |
| diracx.osDbs.default | string | `nil` |  |
| diracx.pythonModulesToInstall | list | `[]` | List of install specifications to pass to pip before launching each container |
| diracx.service.port | int | `8000` |  |
| diracx.settings | object | "e.g. DIRACX_CONFIG_BACKEND_URL=..." | Settings to inject into the API container via environment variables |
| diracx.settings.DIRACX_CONFIG_BACKEND_URL | string | `"git+https://gitlab.invalid/myvo/diracx-config"` | URL to get the diracx config |
| diracx.settings.DIRACX_SANDBOX_STORE_BUCKET_NAME | string | `"sandboxes-store"` | Name of the bucket for the sandbox |
| diracx.settings.DIRACX_SERVICE_AUTH_TOKEN_KEYSTORE | string | `"file:///keystore/jwks.json"` | path storing the token key |
| diracx.sqlDbs.dbs | string | `nil` | Which DiracX MySQL DBs are used? |
| diracx.sqlDbs.default | string | `nil` | default credentials |
| diracxWeb.branch | string | `""` |  |
| diracxWeb.repoURL | string | `""` | install specification to pass to npm before launching container |
| diracxWeb.service.port | int | `8080` |  |
| elasticsearch."discovery.seed_hosts"[0] | string | `"elasticsearch-master-headless"` |  |
| elasticsearch.clusterHealthCheckParams | string | `"local=true"` |  |
| elasticsearch.enabled | bool | `false` |  |
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
| global.activeDeadlineSeconds | int | `900` | timeout for job deadlines |
| global.batchJobTTL | int | `600` | How long should batch jobs be retained after completing? |
| global.imagePullPolicy | string | `"Always"` |  |
| global.images.busybox.repository | string | `"busybox"` |  |
| global.images.busybox.tag | string | `"latest"` |  |
| global.images.client | string | `"ghcr.io/diracgrid/diracx/client"` |  |
| global.images.services | string | `"ghcr.io/diracgrid/diracx/services"` |  |
| global.images.tag | string | `"v0.0.1a49"` |  |
| global.images.web.repository | string | `"ghcr.io/diracgrid/diracx-web/static"` |  |
| global.images.web.tag | string | `"v0.1.0-a10"` |  |
| global.storageClassName | string | `"standard"` |  |
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
| grafana.enabled | bool | `false` |  |
| grafana.service.nodePort | int | `32004` |  |
| grafana.service.port | int | `32004` |  |
| grafana.service.type | string | `"NodePort"` |  |
| grafana.sidecar.dashboards.enabled | bool | `true` |  |
| grafana.sidecar.dashboards.folder | string | `"/var/lib/grafana/dashboards/default"` |  |
| grafana.sidecar.dashboards.label | string | `"grafana_dashboard"` |  |
| grafana.sidecar.dashboards.labelValue | string | `"1"` |  |
| indigoiam.config.initial_client.id | string | `nil` |  |
| indigoiam.config.initial_client.secret | string | `nil` |  |
| indigoiam.config.issuer | string | `"http://anything:32003"` |  |
| indigoiam.enabled | bool | `false` |  |
| indigoiam.image.repository | string | `"indigoiam/iam-login-service"` |  |
| indigoiam.image.tag | string | `"v1.8.3.rc.20231211"` |  |
| indigoiam.service.nodePort | int | `32003` |  |
| indigoiam.service.port | int | `8080` |  |
| indigoiam.service.type | string | `"NodePort"` |  |
| ingress.annotations | object | `{}` |  |
| ingress.className | string | `"nginx"` |  |
| ingress.enabled | bool | `true` |  |
| ingress.tlsSecretName | string | `"myingress-cert"` |  |
| initKeyStore.enabled | bool | `true` |  |
| initOs.enabled | bool | `true` |  |
| initSecrets.enabled | bool | `true` |  |
| initSecrets.rbac.create | bool | `true` |  |
| initSecrets.serviceAccount.create | bool | `true` |  |
| initSecrets.serviceAccount.enabled | bool | `true` |  |
| initSecrets.serviceAccount.name | string | `nil` |  |
| initSql.enabled | bool | `true` |  |
| initSql.env | object | `{}` |  |
| jaeger.agent.enabled | bool | `false` |  |
| jaeger.allInOne.enabled | bool | `true` |  |
| jaeger.collector.enabled | bool | `false` |  |
| jaeger.enabled | bool | `false` |  |
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
| mysql.image.repository | string | `"bitnamilegacy/mysql"` |  |
| mysql.initdbScriptsConfigMap | string | `"mysql-init-diracx-dbs"` |  |
| nameOverride | string | `""` | type=kubernetes.io/dockerconfigjson imagePullSecrets:   - name: regcred |
| nodeSelector | object | `{}` |  |
| opensearch.config | object | `{}` |  |
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
| opentelemetry-collector.config.exporters.prometheus.resource_to_telemetry_conversion.enabled | bool | `true` |  |
| opentelemetry-collector.config.exporters.prometheus.send_timestamps | bool | `true` |  |
| opentelemetry-collector.config.receivers.jaeger | string | `nil` |  |
| opentelemetry-collector.config.receivers.otlp.protocols.grpc | string | `nil` |  |
| opentelemetry-collector.config.receivers.otlp.protocols.http | string | `nil` |  |
| opentelemetry-collector.config.receivers.prometheus | string | `nil` |  |
| opentelemetry-collector.config.service.pipelines.logs.exporters[0] | string | `"elasticsearch/log"` |  |
| opentelemetry-collector.config.service.pipelines.logs.exporters[1] | string | `"logging"` |  |
| opentelemetry-collector.config.service.pipelines.logs.receivers[0] | string | `"otlp"` |  |
| opentelemetry-collector.config.service.pipelines.metrics.exporters[0] | string | `"prometheus"` |  |
| opentelemetry-collector.config.service.pipelines.metrics.exporters[1] | string | `"logging"` |  |
| opentelemetry-collector.config.service.pipelines.metrics.receivers[0] | string | `"otlp"` |  |
| opentelemetry-collector.config.service.pipelines.traces.exporters[0] | string | `"otlp/jaeger"` |  |
| opentelemetry-collector.config.service.pipelines.traces.exporters[1] | string | `"logging"` |  |
| opentelemetry-collector.config.service.pipelines.traces.receivers[0] | string | `"otlp"` |  |
| opentelemetry-collector.enabled | bool | `false` |  |
| opentelemetry-collector.mode | string | `"deployment"` |  |
| opentelemetry-collector.ports.promexp.containerPort | int | `8889` |  |
| opentelemetry-collector.ports.promexp.enabled | bool | `true` |  |
| opentelemetry-collector.ports.promexp.hostPort | int | `8889` |  |
| opentelemetry-collector.ports.promexp.protocol | string | `"TCP"` |  |
| opentelemetry-collector.ports.promexp.servicePort | int | `8889` |  |
| opentelemetry-collector.presets.kubeletMetrics.enabled | bool | `false` |  |
| opentelemetry-collector.presets.kubernetesAttributes.enabled | bool | `false` |  |
| opentelemetry-collector.presets.logsCollection.enabled | bool | `false` |  |
| podAnnotations | object | `{}` |  |
| podSecurityContext | object | `{}` |  |
| prometheus.alertmanager.enabled | bool | `false` |  |
| prometheus.enabled | bool | `false` |  |
| prometheus.kube-state-metrics.enabled | bool | `false` |  |
| prometheus.prometheus-node-exporter.enabled | bool | `false` |  |
| prometheus.server.persistentVolume.enabled | bool | `false` |  |
| prometheus.serverFiles."prometheus.yml".scrape_configs[0].job_name | string | `"otel"` |  |
| prometheus.serverFiles."prometheus.yml".scrape_configs[0].scrape_interval | string | `"10s"` |  |
| prometheus.serverFiles."prometheus.yml".scrape_configs[0].static_configs[0].targets[0] | string | `"diracx-demo-opentelemetry-collector:8889"` |  |
| rabbitmq.auth.existingErlangSecret | string | `"rabbitmq-secret"` |  |
| rabbitmq.auth.existingPasswordSecret | string | `"rabbitmq-secret"` |  |
| rabbitmq.containerSecurityContext.enabled | bool | `false` |  |
| rabbitmq.enabled | bool | `false` |  |
| rabbitmq.podSecurityContext.enabled | bool | `false` |  |
| replicaCount | int | `1` |  |
| replicaCountWeb | int | `1` |  |
| securityContext | object | `{}` |  |
| serviceAccount.annotations | object | `{}` | Annotations to add to the service account |
| serviceAccount.create | bool | `true` | Specifies whether a service account should be created |
| serviceAccount.name | string | `""` | The name of the service account to use. If not set and create is true, a name is generated using the fullname template |
| tolerations | list | `[]` |  |

----------------------------------------------
Autogenerated from chart metadata using [helm-docs v1.14.2](https://github.com/norwoodj/helm-docs/releases/v1.14.2)

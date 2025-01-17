# Helm chart for DiracX

This helm chart is intended to be used in two ways:

 * Development: The ./run_demo.sh script allows the infrastructure to be ran locally with docker+kind
 * Production: TODO

![Version: 0.1.0](https://img.shields.io/badge/Version-0.1.0-informational?style=flat-square) ![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square) ![AppVersion: 0.0.1a](https://img.shields.io/badge/AppVersion-0.0.1a-informational?style=flat-square)

![DiracX Chart tests](https://github.com/DIRACGrid/diracx-charts/actions/workflows/main.yml/badge.svg?branch=master)

## Workflow

This chart can be used for 4 different installation type:

* demo/dev: we install everything and configure everything with pre-configured values (see [below](##running_locally))
* prod: you already have a DIRAC installation with it's own DBs and everything, so you want to create a cluster, but bridge on existing external resources (like DBs)
* New: you start from absolutely nothing (no DIRAC), and you want to install all the dependencies
* New without dependencies: you start with nothing, but you want to use externally managed resources (like DB provided by your IT service)

Depending on the installation you perform, some tasks may be necessary or not. The bottom line is that to simplify the various cases, we want to be able to always run the initialization steps (like DB initialization, or CS initialization) but they should be adiabatic and non destructive.

To understand how the chart operates, see [reference](./docs/REFERENCE.md)

## What this chart contains

This chart contains the deployment for ``diracx`` and ``diracx-web``, as well as dependencies:
* Mysql database
* OpenSearch database
* Dex and IAM as identity provider
* Minio as an object store for the ``SandboxStore``
* OpenTelemetry (see [details](#opentelemetry))

## Intro to Kubernetes and Helm

[Kubernetes](https://kubernetes.io/docs/tutorials/kubernetes-basics/) (k8s) allows you to deploy containerized applications while letting you abstract the underlying infrastructure. The configuration of your application and how you run it is communicated to k8s via ``yaml`` files.

[Helm](https://helm.sh/) allows to template these ``yaml`` files. Such a templated description of an application like ``diracx`` is called ``chart``. Helm also allows to manage dependencies between ``charts``. For example, the ``diracx`` application needs a database to run, so the ``diracx charts`` has a dependency on the ``mysql charts``.

To understand this ``chart`` you will need to familiarize yourself with a few k8s concepts:
* A ``node`` is one of the machine (VM, physical) which sustains your k8s cluster.
* Your application runs inside a container which is part of a ``pod``. A ``pod`` is the atomic unit with which kubernetes will work, and in most cases it corresponds to a single container. ``pods`` are deployed on ``nodes``.
* A ``ReplicaSet`` represents how many ``pods`` of a given type you want to run. For example, you want to run 3 ``pods`` containing the ``diracx`` container for redundancy reasons.
* A ``Deployment`` is how you describe your workload to k8s. It ensures that any number of replicas of your ``pod`` are running (via ``ReplicaSEt``). This chart contains a ``deployment`` for ``diracx`` (see [here](diracx/templates/diracx/deployment.yaml)), and a ``deployment`` for ``diracx-web`` (see [here](diracx/templates/diracx-web/deployment.yaml)). Kubernetes will always make sure that the ``deployment`` is satisfied.
* A ``Service`` is how you expose your ``Deployment``. If I want to talk to my ``diracx`` application, it is a ``Service`` which will take care of redirecting me within the cluster to one of the ``pod``. Most of the time, the ``Service`` is used for routing inside the cluster
* An ``Ingress`` exposes your ``Services`` outside of the cluster.

## Running the demo locally

Running an instance locally is useful for demo or testing purposes. This entails running a local kubernetes cluster, installing this helm chart and all its dependencies, and configuring it accordingly. In order to make that easy, we wrote the ``run_demo.sh`` script, which covers all these needs. This is also used for the [diracx ci](https://github.com/DIRACGrid/diracx/blob/main/.github/workflows/main.yml)

### ``run_demo.sh``

This is the script used to start a demo or the integration tests.

```bash
Usage: run_demo.sh [-h|--help] [--exit-when-done] [--offline] [--enable-coverage] [--no-mount-containerd] [--set-value key=value] [--] [source directories]

  -h|--help: Print this help message and exit
  --exit-when-done: Exit after the demo has been started (it will be left running in the background)
  --enable-coverage: Enable coverage reporting (used by diracx CI)
  --no-editable-python: Do not install Python source directories in editable mode
  --offline: Run in a mode which is suitable for fully offline use.
             WARNING: This may result in some weird behaviour, see the demo documentation for details.
             Implies: --mount-containerd
  --no-mount-containerd: Mount a directory on the host for the kind containerd storage.
                         This option avoids needing to pull container images every time the demo is started.
                         WARNING: There is no garbage collection so the directory will grow without bound.
  --enable-open-telemetry: lauches OpenTelemetry collection.
                           WARNING: experimental and resource hungry.
  --set-value: Set a value in the Helm values file. This can be used to override the default values.
               For example, to enable coverage reporting pass: --set-value developer.enableCoverage=true
  source directories: A list of directories containing Python packages to mount in the demo cluster.
```

Once ready, you will get some information on how to interact with your cluster

```md
NOTES:

🚧 Chart has been installed in developer mode.

ℹ️  To interact with the cluster directly using kubectl/helm you'll need to set the
first following environment variables:

  export KUBECONFIG=/home/chaen/dirac/diracx-project/diracx-charts/.demo/kube.conf
  export HELM_DATA_HOME=/home/chaen/dirac/diracx-project/diracx-charts/.demo/helm_data
  export PATH=${PATH}:/home/chaen/dirac/diracx-project/diracx-charts/.demo

Then see the chart README for more information on how to use kubectl/helm.

ℹ️  To use the demo with the DiracX client set:

  export DIRACX_URL=https://172.18.0.1.nip.io:8000
  export DIRACX_CA_PATH=/home/chaen/dirac/diracx-project/diracx-charts/.demo/demo-ca.pem

ℹ️  To use the demo with a DiracX client without local installation:

  kubectl exec -it  deployment/diracx-demo-cli -- bash

ℹ️  To access the web application visit:

  https://172.18.0.1.nip.io:8000

ℹ️  To access the interactive API documentation visit:

  https://172.18.0.1.nip.io:8000/api/docs

ℹ️  When prompted to login the credentials are:

  Username: admin@example.com
  Password: password

ℹ️  Grafana dashboard for telemetry (if enabled)

  https://172.18.0.1.nip.io:32004

  Username: admin
  Password: run ``kubectl get secrets diracx-demo-grafana -o jsonpath="{.data.admin-password}" | base64 --decode ; echo``

🦄 Waiting for installation to finish...
pod/diracx-demo-7fd5c47cd6-mq8s7 condition met
🎉 🎉 🎉 Pods are ready! 🎉 🎉 🎉
🦄 Creating initial CS content ...
Writing back configuration to /cs_store/initialRepo/default.yml
Successfully added vo to git+file:///cs_store/initialRepo
Writing back configuration to /cs_store/initialRepo/default.yml
Successfully added user to git+file:///cs_store/initialRepo

ℹ️  Press Ctrl+C to clean up and exit
```
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
# Run a command in one of the pods
kubectl exec -it <pod name> -- /bin/bash /entrypoint.sh
```

#### Helm basics

When running the demo,  an `values.yaml` file is created as `.demo/values.yaml`.
This file can be used with helm to interact with the running demo to make changes to what is running in the cluster.

```bash

# Show what will be changed by running "helm upgrade"
# Note: helm diff has a ``bug`` that requires you to specify the existing password
# https://github.com/databus23/helm-diff/issues/460

export RABBITMQ_PASSWORD=$(kubectl get secret --namespace "default" rabbitmq-secret -o jsonpath="{.data.rabbitmq-password}" | base64 -d)
export MYSQL_ROOT_PASSWORD=$(kubectl get secret --namespace "default" mysql-secret -o jsonpath="{.data.mysql-root-password}" | base64 -d)
export MYSQL_PASSWORD=$(kubectl get secret --namespace "default" mysql-secret -o jsonpath="{.data.mysql-password}" | base64 -d)

helm diff upgrade diracx-demo  ./diracx --values .demo/values.yaml --set rabbitmq.auth.password=$RABBITMQ_PASSWORD  --set mysql.auth.rootPassword=$MYSQL_ROOT_PASSWORD --set mysql.auth.password=$MYSQL_PASSWORD

# Actually run "helm upgrade" to apply changes
helm upgrade diracx-demo ./diracx --values .demo/values.yaml
```

See [here](./docs/RUN_DEMO.md) for more details on what you can do to alter the behavior of the local installation.

## Deploying in production

TODO: Link to k3s

TODO: Explain how to download the values from helm

TODO: add info about diracx-web

### Deploying a custom branch to DIRAC certification

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

## OpenTelemetry

> :warning: **Experimental**: opentelemetry is an evolving product, and so is our implementation of it.

``diracx`` aim at relying on [OpenTelemetry](https://opentelemetry.io/) for traces, monitoring and logging. When running in demo mode, this chart can spawn the necessary component for the telemetry to be reported:
* OpenTelemetry-collector to collect all the data
* Prometheus for the metrics
* Jaeger for traces
* ElasticSearch for logs (OpenSearch not yet supported)
* Grafana to display all that (accessible on port 32004 of the demo)

To enable it, run ``run_demo.sh`` with ``enable-open-telemetry``

Note that this configuration is trivial and does not follow production recommandations (like using batch processing)

![OTEL collector configuration](./demo/otel-collector.png)

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
| developer.enabled | bool | `true` |  |
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
| dex.image.tag | string | `"v2.37.0"` |  |
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
| diracx.settings.DIRACX_CONFIG_BACKEND_URL | string | `"git+file:///cs_store/initialRepo"` | This corresponds to the basic dirac.cfg which must be present on all the servers TODO: autogenerate all of these |
| diracx.sqlDbs.dbs | string | `nil` | Which DiracX MySQL DBs are used? |
| diracx.sqlDbs.default | string | `nil` |  |
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
| global.images.tag | string | `"dev"` |  |
| global.images.web.repository | string | `"ghcr.io/diracgrid/diracx-web/static"` |  |
| global.images.web.tag | string | `"dev"` |  |
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
| initCs.enabled | bool | `true` |  |
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
| rabbitmq.enabled | bool | `true` |  |
| rabbitmq.podSecurityContext.enabled | bool | `false` |  |
| replicaCount | int | `1` |  |
| securityContext | object | `{}` |  |
| serviceAccount.annotations | object | `{}` | Annotations to add to the service account |
| serviceAccount.create | bool | `true` | Specifies whether a service account should be created |
| serviceAccount.name | string | `""` | The name of the service account to use. If not set and create is true, a name is generated using the fullname template |
| tolerations | list | `[]` |  |

----------------------------------------------
Autogenerated from chart metadata using [helm-docs v1.11.2](https://github.com/norwoodj/helm-docs/releases/v1.11.2)

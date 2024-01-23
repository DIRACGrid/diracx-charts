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
# Note: helm diff has a ``bug`` that requires you to specify the existing password
# https://github.com/databus23/helm-diff/issues/460

export RABBITMQ_PASSWORD=$(kubectl get secret --namespace "default" rabbitmq-secret -o jsonpath="{.data.rabbitmq-password}" | base64 -d)
export MYSQL_ROOT_PASSWORD=$(kubectl get secret --namespace "default" mysql-secret -o jsonpath="{.data.mysql-root-password}" | base64 -d)
export MYSQL_PASSWORD=$(kubectl get secret --namespace "default" mysql-secret -o jsonpath="{.data.mysql-password}" | base64 -d)

helm diff upgrade diracx-demo  ./diracx --values .demo/values.yaml --set rabbitmq.auth.password=$RABBITMQ_PASSWORD  --set mysql.auth.rootPassword=$MYSQL_ROOT_PASSWORD --set mysql.auth.password=$MYSQL_PASSWORD

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

## Workflow

4 types of installations:
* demo/dev: we install everything and configure everything with pre-configured values
* prod: you already have a DIRAC installation with it's own DBs and everything, so you want to create a cluster, but bridge on existing external resources (like DBs)
* New: you start from absolutely nothing (no DIRAC), and you want to install all the dependencies
* New without dependencies: you start with nothing, but you want to use externally managed resources (like DB provided by your IT service)

Depending on the installation you perform, some tasks may be necessary or not. The bottom line is that to simplify the various cases, we want to be able to always run the initialization steps (like DB initialization, or CS initialization) but they should be adiabatic and non destructive.

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
| cert-manager-issuer.enabled | bool | `true` |  |
| cert-manager.enabled | bool | `true` |  |
| cert-manager.installCRDs | bool | `true` |  |
| developer.autoReload | bool | `true` | Enable automatic reloading inside uvicorn when the sources change Used by the integration tests for running closer to prod setup |
| developer.editableMountedPythonModules | bool | `true` | Use pip install -e for mountedPythonModulesToInstall This is used by the integration tests because editable install might behave differently |
| developer.enableCoverage | bool | `false` | Enable collection of coverage reports (intended for CI usage only) |
| developer.enabled | bool | `true` |  |
| developer.ipAlias | string | `nil` | The IP that the demo is running at |
| developer.localCSPath | string | `"/local_cs_store"` | If set, mount the CS stored localy instead of initializing a default one |
| developer.mountedPythonModulesToInstall | list | `[]` | List of packages which are mounted into developer.sourcePath and should be installed with pip install SOURCEPATH/... |
| developer.nodeImage | string | `"node:16-alpine"` | Image to use for the webapp if nodeModuleToInstall is set |
| developer.nodeModuleToInstall | string | `nil` | List of node modules to install |
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
| diracxWeb.service.port | int | `8080` |  |
| fullnameOverride | string | `""` |  |
| global.activeDeadlineSeconds | int | `900` | timeout for job deadlines |
| global.batchJobTTL | int | `600` | How long should batch jobs be retained after completing? |
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
| init-cs.enabled | bool | `true` |  |
| init-secrets.enabled | bool | `true` |  |
| init-secrets.rbac.create | bool | `true` |  |
| init-secrets.serviceAccount.create | bool | `true` |  |
| init-secrets.serviceAccount.enabled | bool | `true` |  |
| init-secrets.serviceAccount.name | string | `nil` |  |
| init-sql.enabled | bool | `true` |  |
| init-sql.env | object | `{}` |  |
| initOs.enabled | bool | `true` |  |
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
| serviceAccount.annotations | object | `{}` | Annotations to add to the service account |
| serviceAccount.create | bool | `true` | Specifies whether a service account should be created |
| serviceAccount.name | string | `""` | The name of the service account to use. If not set and create is true, a name is generated using the fullname template |
| tolerations | list | `[]` |  |

----------------------------------------------
Autogenerated from chart metadata using [helm-docs v1.11.2](https://github.com/norwoodj/helm-docs/releases/v1.11.2)

# Details of deploying `diracx` in production

The aim of this documentation is to give pointers on how to install the `diracx-charts` longside an existing `DIRAC` installation.

Effectively, this means that you will be using your existing databases (`MySQL`, `OpenSearch`), and just install the new dependencies of `diracx`.

We go here with the assumption that you have a `kubernetes` cluster at hand. If you do no have one, see the [k3s example](../k3s/README.md).


If your central infrastructure already provide the following services, by all mean, use them.


## Cert manager

TODO with letsencrypt

```yaml
cert-manager:
  enabled: false
cert-manager-issuer:
  enabled: false
```

## Admin VO


A new concept in `diracx` is the `AdminVO`, which has super karma on `diracx` itself but not on the resources the VO use.

We recommand using [dex](https://github.com/dexidp/dex) as the IdP for that. The [helper script](dex_config_helper.sh) can assist you in that.




```yaml
dex:
  enabled: false
```



## CS


```yaml
init-cs:
  enabled: true
```

## Ingress

```yaml
ingress:
  annotations:
    haproxy.router.openshift.io/ip_whitelist: ""
    route.openshift.io/termination: edge
  className: null
  enabled: true
  tlsSecretName: null
```
## Sandbox

```yaml
minio:
  enabled: false
```


## DiracX configuration


```yaml
diracx:
  hostname: diracx-cert.app.cern.ch
```

```yaml
global:
  images:
    client: ghcr.io/diracgrid/diracx/client
    services: ghcr.io/diracgrid/diracx/services
    tag: dev
    web:
      repository: ghcr.io/diracgrid/diracx-web/static
      tag: dev
```



```yaml
init-secrets:
  enabled: true
init-sql:
  enabled: false
initOs:
  enabled: true

mysql:
  enabled: false
opensearch:
  enabled: false
rabbitmq:
  enabled: false
```

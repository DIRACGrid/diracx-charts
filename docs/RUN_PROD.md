# Details of deploying `diracx` in production

The aim of this documentation is to give pointers on how to install the `diracx-charts` longside an existing `DIRAC` installation.

Effectively, this means that you will be using your existing databases (`MySQL`, `OpenSearch`), and just install the new dependencies of `diracx`.

We go here with the assumption that you have a `kubernetes` cluster at hand. If you do no have one, see the [k3s example](../k3s/README.md).


If your central infrastructure already provide the following services, by all mean, use them.

More configuration options are available, please refer to the [values.yaml](../diracx/values.yaml)

## Getting started

You can generate a template for your installation using
`dirac internal legacy generate-helm-values`

This file still needs to be edited (look for `TODO`).
The following sections give you more details.

## IDP

To authenticate a VO, you need an IDP that can work with the Oauth2 Authorization with PKCE.

How you exactly configure it is idp dependant, but here are the basics:

* Redirection URLs should be the following
```
https://<youdiracx.invalid>/api/auth/device/complete
https://<youdiracx.invalid>/api/auth/authorize/complete
```
* The client should be public (no authentication)
* The necessary scopes are `email`, `openid`, `profile`
* The needed grant type is authorization flow


You can for example use [CERN SSO](SSO.md) as an IdP.

Note that you still need to have the users registered in `diracx` by filling the `CsSync` section in the CS.


## Cert manager

### letsencrypt
TODO


### Openshift

Openshift takes care of distributing certificates to the ingress

```yaml
cert-manager:
  enabled: false
cert-manager-issuer:
  enabled: false
```

## Admin VO


A new concept in `diracx` is the `AdminVO`, which has super karma on `diracx` itself but not on the resources the VO use.

We recommand using the SSO of your institute of it supports it (see [IdP](#idp)).
Otherwise, [dex](https://github.com/dexidp/dex) is a good choice. You can either have local account (the [helper script](dex_config_helper.sh) can assist you in that), or use `dex` as a redirector for external IdP, which may not support PKCE flow (like `EGI CheckIn`)


```yaml
dex:
  enabled: false
```


## CS

We recommend taking the configuration from a git repository (gitlab, github, ...).

This is controled with the `DIRACX_CONFIG_BACKEND_URL` setting.

For example:

```yaml
diracx:
  settings:
    DIRACX_CONFIG_BACKEND_URL: git+https://<token-name>:<token-value>@gitlab.cern.ch/lhcb-dirac/lhcbdiracx-cert-conf.git
```

If you want to use another branch than `master`, you can add a parameter at the end `?branch_name=something_else`.

Instructions for conversion from the `DIRAC CS` to the `diracx config` can be found [here](https://github.com/DIRACGrid/diracx/blob/main/docs/CONFIGURATION.md)



## Ingress controller

This is very infrastructure dependant. In any case, we expect that the CertManager or your infrastructure is capable of delivering you certificates.

### Openshift


```yaml
ingress:
  annotations:
    haproxy.router.openshift.io/ip_whitelist: ""
    route.openshift.io/termination: edge
  className: null
  enabled: true
  # Openshift takes care of filling in certificates
  tlsSecretName: null
```

### K3S

```yaml
ingress:
  className: "traefik"
```

## Sandbox

The Sandbox needs to be an object store. We highly recommend that you use one provided by your institute.

The connections parameters are controlled with

```yaml
diracx:
  settings:
    DIRACX_SANDBOX_STORE_BUCKET_NAME: sandboxes-store
    DIRACX_SANDBOX_STORE_S3_CLIENT_KWARGS: '{"endpoint_url": "http://minio.invalid:32000", "aws_access_key_id": "my-access-key", "aws_secret_access_key": "my-secret-key-123"}'
    DIRACX_SANDBOX_STORE_AUTO_CREATE_BUCKET: "true"
```

To avoid running minio:

```yaml
minio:
  enabled: false
```

## Databases

You should be running against the existing `DIRAC` databases, so we do not recommend deploying the DB in your cluster using this chart.

### SQL

The access to the database is controlled by the following values.
Every DB which is used should be configured.

```yaml
diracx:
  sqlDbs:
    default:
         rootUser: admin
         rootPassword: hunter123
         user: dirac
         password: password123
         host: sqlHost:123
    dbs:
      AuthDB:
        internalName: DiracXAuthDB
      JobDB:
```

You can chose whether you prefer to create the DB yourself or let `diracx` do it.

```yaml
# Create the DB and the schema if set to True
init-sql:
  enabled: false

# Disable the installation of mysql
mysql:
  enabled: fase
```

The command being executed is

```python
python -m diracx.db init-sql
```


Note that these options will generate mysql urls only. Should you need another DB,
you should write the URL yourself in the settings, for example

```yaml
diracx:
  settings:
    DIRACX_DB_URL_BOOKKEEPINGDB: oracle+oracledb_async://ACCOUNT:PASSWORD@itrac1234.cern.ch/?service_name=int123.cern.ch
```

### Opensearch DB

The setup is the same as for the SQL dbs

```yaml
diracx:
  osDbs:
    dbs:
      JobParametersDB: null
      PilotLogsDB: null
    default:
      host: os-dirac.cern.ch:443/os
      password: secret123
      rootPassword: secret1234
      rootUser: sangoku
      user: vegeta
```


You can chose to initialize the DBs yourself or let `diracx` do it.

```yaml
initOs:
  enabled: true
```

The command executed is

```python
python -m diracx.db init-os
```


## DiracX service configuration

The configuration for the service itself is minimal and just requires the hostname

```yaml
diracx:
  hostname: diracx-cert.app.cern.ch
```

You can also configure the images and the registry that are used


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


## Secrets management

The secrets are managed by the following flag

```yaml
initSecrets:
  enabled: true
```

It will make sure to generate the appropriate settings from the db configurations, generate token signing keys if not present, etc

We recommend you leave it to `true`.

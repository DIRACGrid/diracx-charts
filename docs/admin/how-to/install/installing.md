
# Installing DiracX


The aim of this documentation is to give pointers on how to install the `diracx-charts` alongside an existing `DIRAC` installation.

Effectively, this means that you will be using your existing databases (`MySQL`, `OpenSearch`), and just install the new dependencies of `diracx`.

## Prerequisites


??? note "A Kubernetes cluster available"
    Which ever it is, at the stage we expect that you have a fully functional kubernetes cluster available. If it is not the case, check the [k3s how-to](./install-kubernetes.md)

??? note "A running `DIRAC` installation. "
    DiracX always has to run in parallel of a `DIRAC v9` installation.
    In particular, make sure that the `DiracX` section of the `DIRAC CS` has been filled properly following the  Dirac V9 migration guide


??? note "Access to [kubectl](https://kubernetes.io/docs/tasks/tools/#kubectl) and [helm](https://helm.sh/docs/intro/install/#from-script)"

    ```bash
    # kubectl
    curl -LO https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl

    # kubectl checksum file
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl.sha256"

    # validate binary
    echo "$(cat kubectl.sha256)  kubectl" | sha256sum --check

    # install
    sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl


    curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
    chmod 700 get_helm.sh
    ./get_helm.sh
    ```

??? note "The `kubeconfig` file to connect to your cluster"

    See the [k3s docs](https://docs.k3s.io/cluster-access) if you installed it.


## Configure the DiracX URL in DIRAC

You are about to deploy a `DiracX` instance on a cluster. That instance will be reachable by a URL, like `mydiracx.k8s.institute.invalid`. This URL needs to be configured in the DIRAC CS.

```
DiracX
{
    URL = mydiracx.k8s.institute.invalid
}
```


!!! question "Why do I need it in DIRAC"

    Because `DIRAC` interacts heavily with `DiracX` such that the migration can be smooth, and because the following tools expects to find this information in the CS

## Install `diracx` client

`DiracX` comes with a few utilities to ease its installation.


```bash  title="<code>$ pip install diracx</code>"
Installing collected packages: wrapt, urllib3, typing-extensions, sniffio, smmap, six, shellingham, sh, pyyaml, python-dotenv, pyjwt, pygments, pycparser, propcache, multidict, mdurl, jmespath, isodate, idna, h11, frozenlist, dnspython, diraccfg, click, charset_normalizer, certifi, cachetools, attrs, annotated-types, aioitertools, aiohappyeyeballs, yarl, typing-inspection, requests, python-dateutil, pydantic-core, markdown-it-py, httpcore, gitdb, email-validator, cffi, anyio, aiosignal, rich, pydantic, httpx, gitpython, cryptography, botocore, azure-core, aiohttp, typer, pydantic-settings, joserfc, aiobotocore, diracx-core, diracx-client, diracx-api, diracx-cli, diracx
Successfully installed aiobotocore-2.23.2 aiohappyeyeballs-2.6.1 aiohttp-3.12.15 aioitertools-0.12.0 aiosignal-1.4.0 annotated-types-0.7.0 anyio-4.10.0 attrs-25.3.0 azure-core-1.35.0 botocore-1.39.8 cachetools-6.1.0 certifi-2025.8.3 cffi-1.17.1 charset_normalizer-3.4.2 click-8.2.1 cryptography-45.0.6 diraccfg-1.0.1 diracx-0.0.1a46 diracx-api-0.0.1a46 diracx-cli-0.0.1a46 diracx-client-0.0.1a46 diracx-core-0.0.1a46 dnspython-2.7.0 email-validator-2.2.0 frozenlist-1.7.0 gitdb-4.0.12 gitpython-3.1.45 h11-0.16.0 httpcore-1.0.9 httpx-0.28.1 idna-3.10 isodate-0.7.2 jmespath-1.0.1 joserfc-1.2.2 markdown-it-py-3.0.0 mdurl-0.1.2 multidict-6.6.3 propcache-0.3.2 pycparser-2.22 pydantic-2.11.7 pydantic-core-2.33.2 pydantic-settings-2.10.1 pygments-2.19.2 pyjwt-2.10.1 python-dateutil-2.9.0.post0 python-dotenv-1.1.1 pyyaml-6.0.2 requests-2.32.4 rich-14.1.0 sh-2.2.2 shellingham-1.5.4 six-1.17.0 smmap-5.0.2 sniffio-1.3.1 typer-0.16.0 typing-extensions-4.14.1 typing-inspection-0.4.1 urllib3-2.5.0 wrapt-1.17.2 yarl-1.20.1

```


Congrats, you have just installed the `diracx` client.

```bash  title="<code>$ dirac --help</code>"

 Usage: dirac [OPTIONS] COMMAND [ARGS]...

╭─ Options ──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────╮
│ --output-format             TEXT  [default: None]                                                                                                                                                                                          │
│ --install-completion              Install completion for the current shell.                                                                                                                                                                │
│ --show-completion                 Show completion for the current shell, to copy it or customize the installation.                                                                                                                         │
│ --help                            Show this message and exit.                                                                                                                                                                              │
╰────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────╯
╭─ Commands ─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────╮
│ login    Login to the DIRAC system using the device flow.                                                                                                                                                                                  │
│ whoami                                                                                                                                                                                                                                     │
│ logout                                                                                                                                                                                                                                     │
│ config                                                                                                                                                                                                                                     │
│ jobs                                                                                                                                                                                                                                       │
╰────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────╯

```


## Generate the helm configuration files


The  `DiracX` installation is configured via a `Helm values.yaml` tailored to your needs. A lot of the configuration needed by `DiracX` is already contained in the `DIRAC CS`. Other parts like secrets (DB passwords, etc) are typically found in the local `dirac.cfg` used by the `DIRAC` services.

`DiracX` provide a tool to combine these 2 files and generate a `values.yaml` to get you started:


```bash
$ dirac internal legacy generate-helm-values --public-cfg public_cs.cfg --secret-cfg dirac_secret.cfg --output-file my_values.yaml

    The file is incomplete and needs manual editing (grep for 'FILL ME')
```

The file generated looks like the following

??? example "my_values.yaml"

    ```yaml
    cert-manager:
        enabled: false
    cert-manager-issuer:
        enabled: false
    developer:
        enabled: false
    dex:
        enabled: false
    diracx:
        hostname: mydiracx.k8s.institute.invalid
        osDbs:
            dbs:
                JobParametersDB: null
            default:
                host: FILL ME
                password: DiracOsPassword
                rootPassword: FILL ME
                rootUser: FILL ME
                user: DiracOSUser
        settings:
            DIRACX_CONFIG_BACKEND_URL: FILL ME
            DIRACX_LEGACY_EXCHANGE_HASHED_API_KEY: aafabc9c0b8f7e6c0eaed8cee9acbda187fdd90f59d7975dae9b478a1c4be8ae
            DIRACX_SANDBOX_STORE_AUTO_CREATE_BUCKET: "true"
            DIRACX_SANDBOX_STORE_BUCKET_NAME: diracx-sandboxes
            DIRACX_SANDBOX_STORE_S3_CLIENT_KWARGS: '{"endpoint_url": "FILL ME", "aws_access_key_id": "FILL ME", "aws_secret_access_key": "FILL ME"}'
            DIRACX_SANDBOX_STORE_SE_NAME: ProductionSandboxSE
            DIRACX_SERVICE_AUTH_ALLOWED_REDIRECTS:
                '["https://mydiracx.k8s.institute.invalid/api/docs/oauth2-redirect",
                "https://mydiracx.k8s.institute.invalid/#authentication-callback"]'
            DIRACX_SERVICE_AUTH_TOKEN_ISSUER: https://mydiracx.k8s.institute.invalid
            DIRACX_SERVICE_JOBS_ENABLED: "true"
        sqlDbs:
            dbs:
                AuthDB:
                    internalName: DiracXAuthDB
                JobDB: null
                JobLoggingDB: null
                PilotAgentsDB: null
                SandboxMetadataDB: null
                TaskQueueDB: null
            default:
                host: FILL ME:FILL ME
                password: DiracPassword
                rootPassword: FILL ME
                rootUser: FILL ME
                user: DiracUser
    ingress:
        annotations:
            haproxy.router.openshift.io/ip_whitelist: ""
            route.openshift.io/termination: edge
        className: null
        enabled: true
        tlsSecretName: null
    initCs:
        enabled: true
    initSecrets:
        enabled: true
    initSql:
        enabled: false
    minio:
        enabled: false
    mysql:
        enabled: false
    opensearch:
        enabled: false
    rabbitmq:
        enabled: false

    ```

As you can see, a lot of information are still missing, and it is up to you to fill them in.


## Create the DiracXAuthDB

`DiracX` needs one extra database with respect to DIRAC to manage its authentication, that you need to create by hand:

```sql
CREATE DATABASE IF NOT EXISTS `DiracXAuthDB`;
GRANT SELECT, INSERT, UPDATE, DELETE, INDEX, CREATE TEMPORARY TABLES, LOCK TABLES ON DiracXAuthDB.* TO '<dirac_sql_user>'@'%';
```

!!! warning "This is not the DIRAC AuthDB"

    `DIRAC` also has an `AuthDB`, but it is entirely different.


!!! warning "Check the DiracXAuthDB connection configuration"

    If you decided to create the `DiracXAuthDB` on a different host than the default one, you may need to customize it in your `values.yaml` as there is no information about it in `DIRAC`. All the default values can be overwriten at a DB level, for example:

    ```yaml
    sqlDbs:
        dbs:
        AuthDB:
            internalName: DiracXAuthDB
            host: otherhost:123

    ```

## DiracX Config URL

This should be the URL of the repository populated by synchronizing the CS. You should already have completed the CS synchronization step. For more details about the configuration, see the [dedicated explanations](../../explanations/configuration.md)

!!! note "You do not need write permissions"

    For the forseable future, this repository will only be read by `diracx`

!!! example "<code>DIRACX_CONFIG_BACKEND_URL=git+https://username:read-token@github.com/myrepo/diracx-conf.git</code>"


## Sandbox URL

The [DiracX SandboxStore](../../explanations/sandbox-store.md) stores files on an object store. The `DIRACX_SANDBOX_STORE_S3_CLIENT_KWARGS` should contain the credentials for it

!!! example "DIRACX_SANDBOX_STORE_S3_CLIENT_KWARGS"

    ```json
    '{"endpoint_url": "https://mys3.invalid",
      "aws_access_key_id": "21kkdak4324jkj4234m3", "aws_secret_access_key":
      "sdalkja34983204923kds"}'
    ```

??? question "What if I don't have an object store at hand?"

    * Investigate if there is a plugin for any storage system you already run (e.g. [CEPH](https://docs.ceph.com/en/latest/radosgw/s3/))
    * Consider investing in a public cloud storage
    * If you have to install it yourself, we recommand installing [Minio](https://www.min.io/).


## Ingress configuration

The [cert-manager](https://cert-manager.io/docs/usage/ingress/) documentation explains how it interacts with an `ingress`.
The `ingress controller` is normally dictated by your kubernetes installation. We write here a few examples of configuration, depending on your setup.

In all the example below, we assume your Helm release is called `<release-name>`


=== "Openshift"

    At CERN for example.

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

=== "Traefik"

    For a installation with Traefik (like k3s) with a Let's Encrypt certificate.

    ```yaml
    ingress:
        enabled: true
        annotations:
            cert-manager.io/issuer: <release-name>-issuer
        className: traefik
        tlsSecretName: <release-name>-ingress-cert

    acme:
        enabled: true
        server: https://acme-staging-v02.api.letsencrypt.org/director

    ```

=== "Nginx"

    For an `Nginx` ingress, with a Let's Encrypt certificate,

    [cert-manager](https://cert-manager.io/docs/tutorials/acme/nginx-ingress/) has a detailed documentation for that.

    ```yaml
    ingress:
        enabled: true
        annotations:
            cert-manager.io/issuer: <release-name>-issuer
            className: nginx
            tlsSecretName: <release-name>-ingress-cert

    acme:
        enabled: true
        server: https://acme-staging-v02.api.letsencrypt.org/director


    ```

## Deploy diracx on your cluster

First of all, you need to clone the [diracx-chart](https://github.com/DIRACGrid/diracx-charts) repository.


=== "SSH"

    ```bash
    git clone git@github.com:DIRACGrid/diracx-charts.git
    ```

=== "GitHub CLI"

    ```bash
    gh repo fork DIRACGrid/diracx-charts # (1)!
    ```

    1. The GitHub CLI can be installed as a [`pixi global` tool](https://pixi.sh/dev/global_tools/introduction/) using:

        ```bash
        pixi global install gh
        ```

=== "HTTPS"

    ```bash
    git clone https://github.com/DIRACGrid/diracx-charts.git
    ```


!!! question "Why do I need to clone the repository?"

    In the near future, there will be a proper URL for a helm repo, and you will not need to clone the git repository anymore.

You can now deploy `diracx`

``` bash
helm install --timeout 3600s <release-name> ./diracx-charts/diracx/ -f my_values.yaml
```

!!! question "What is this release name anyway ?"

    This is to identify a given installation of a chart on a given cluster. This allows to install the same chart multiple time on the same cluster. The [Helm documentation](https://helm.sh/docs/intro/using_helm/) has extended explanations.


!!! success "Congrats, you have installed DiracX"

    However, it does not do anything so far... See the [following steps](register-the-admin-vo.md)

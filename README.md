# Helm chart for DiracX

This helm chart is intended to be used in two ways:

 * Development: The ./run_demo.sh script allows the infrastructure to be ran locally with docker+kind
 * Production: TODO

![Version: 0.1.0-alpha.2](https://img.shields.io/badge/Version-0.1.0--alpha.2-informational?style=flat-square) ![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square) ![AppVersion: 0.0.1a](https://img.shields.io/badge/AppVersion-0.0.1a-informational?style=flat-square)

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

## Deploying in production

TODO: Link to k3s

TODO: Explain how to download the values from helm

TODO: add info about diracx-web

# Details of ``run_demo.sh``

## What ``run_demo.sh`` does

In order to run the ``diracx charts`` locally, this script:
* downloads various utilities (``kind``, ``helm``, ``kubectl``, etc)
* Starts a local kubernetes using [kind](https://kind.sigs.k8s.io/)
* Installs the ``chart`` using ``helm``, enabling all the dependencies (DBs, IdP, Object store, etc)
* Generate the initial configuration for all the dependencies and ``diracx`` (db credentials, urls of services, create admin users, etc)

All this relies on templated configuration in the [demo](../demo/) directory. A temporary folder (``diracx-charts/.demo``) is used to generate the actual config and host various tools. It is important for this directory to have a deterministic location as it is used by the ``diracx`` integration tests.

## Mounted containers

``kind`` creates a docker container, and runs kubernetes inside. In order to avoid that ``kind`` downloads the ``diracx`` and dependencies images everytime, ``run_demo.sh`` creates a docker volume ``diracx-demo-containerd`` that is mounted in the container in which the images are stored.
This volume could grow very large, do not forget to clean it up regularely, as suggested by the ``run_demo.sh`` script

```bash
⚠️ Volume for containerd is 21 GB, if you want to save space shutdown the demo and run "docker volume rm diracx-demo-containerd"
```

## DiracX configuration

The configuration yaml used by the ``diracx`` service is a mounted directory: ``diracx-charts/.demo/cs-mount``.  This means that if you want to change the configuration of diracx, you can just edit ``diracx-charts/.demo/cs-mount/initRepo/default.yml`` and ``git commit`` this file. Note that the ``diracx-charts/.demo/cs-mount`` is a git repository in itself, and that's where you should go and commit. Do not attempt to commit anything under ``diracx-charts/.demo/`` in the ``diracx-charts`` repo (it is in the ``.gitignore``)

## Coverage volume

In order for the ``diracx CI`` to collect and aggregate coverage report, a local path is mounted inside the container ``diracx-charts/.demo/coverage-reports``.

## Mounted python module

Because you may want to test changes in ``diracx`` itself, or ``DIRAC`` or any other python package, listing these packages at the end of the ``run_demo.sh`` command line will mount these directories and (by default) perform an editable install of these packages.

Effectively, that means that you can do ``diracx-charts/run_demo.sh <mydiracxcheckout>``, edit the code of your ``diracx`` checkout, and see it run directly in the demo.

## Mounted node module
Because you may want to test changes in ``diracx-web`` itself, appending the package at the end of the ``run_demo.sh`` command line will mount the directory and (by default) perform an editable install of the package.
Effectively, that means that you can do ``diracx-charts/run_demo.sh <mydiracx-webcheckout>``, edit the code of your ``diracx-web`` checkout, and see it run directly in the demo.

## CA certificates

The ``run_demo.sh`` generates a self signed certificate and dumps it in ``diracx-charts/.demo/demo-ca.pem`` to allow for a local client to interact with it.


## Secret generation

Multiple secrets are needed for ``diracx`` to run. In the case of the demo, they are auto generated, and are persisted during ``helm upgrade``

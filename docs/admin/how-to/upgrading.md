# Upgrading diracx in your cluster

!!! warning "Version compatibility"

    DiracX should be upgraded before upgrading legacy DIRAC installations.

Upgrades are managed via ``helm`` but can either be done manually, or in an automated way.

## Manual upgrade

First, update the ``values.yaml`` if you need to. Then simply run

``` bash
helm upgrade --timeout 3600s --wait --cleanup-on-fail <release-name> diracx -f my_values.yaml
```

## Automated update

Some tools can assist you managing clusters. There are two main tools: ``ArgoCD`` and ``Flux2``.

### ArgoCD

[ArgoCD](https://argo-cd.readthedocs.io/) is a very popular tool to manage clusters and automate releases. However, it does not play nicely with Helm charts using hooks for pre/post jobs, which ``diracx-charts`` does. Unfortunately, it means ``ArgoCD`` will not work for `diracx`.

### Flux

[Flux2](https://github.com/fluxcd/flux2) is an alternative which does not suffer from the hook flaws of ``ArgoCD``. However, in order to run, ``Flux2`` needs to have ``Operators`` available on the cluster, which some cluster do not allow (e.g. Openshift @ CERN).


### Gitlab automation

The steps involved into automating the release process using gitlab CI are easy, and are described in the [installation how-to](../../dev//how-to/make-a-release.md)

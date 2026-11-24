# Mount Extra Volumes

Some deployments need extra files inside the DiracX containers, the most common case being a CA trust store (e.g. the EGI trust store, or a development CA used for self-signed certificates).
The chart supports this through two values:

- `global.extraVolumes`: a list of [Kubernetes volumes](https://kubernetes.io/docs/concepts/storage/volumes/) added to every pod running a DiracX image.
- `global.extraVolumeMounts`: a list of volume mounts added to every container running a DiracX image.

They apply to the DiracX services, the CLI, the task scheduler and workers, and the `init-cs`, `init-os`, `init-sql`, `init-keystore`, `validate-config` and `cleanup-authdb` jobs.
They are not applied to helper containers that do not run DiracX code (busybox `wait-for-*`, secret generation, `diracx-web`, redis, ...).

Both lists are copied verbatim into the pod spec, so any volume source supported by Kubernetes can be used.

!!! warning

    The chart does not create the objects referenced by these volumes.
    The ConfigMap, Secret or PersistentVolumeClaim must already exist in the release namespace **before** running `helm install`, as some of the jobs using them run as `pre-install` hooks.
    If the object is missing, the pods stay in `ContainerCreating` (unless `optional: true` is set on a ConfigMap or Secret source).

!!! note

    The values are not templated: names such as `{{ .Release.Name }}-ca` are used literally.

## From a ConfigMap

```yaml
global:
  extraVolumes:
    - name: extra-ca
      configMap:
        name: my-ca-bundle
  extraVolumeMounts:
    - name: extra-ca
      mountPath: /etc/pki/ca-trust/source/anchors
      readOnly: true
```

## From a Secret

A single key of a Secret can be mounted as one file using `subPath`:

```yaml
global:
  extraVolumes:
    - name: dev-ca
      secret:
        secretName: dev-root-ca
        items:
          - key: ca.crt
            path: dev-ca.pem
  extraVolumeMounts:
    - name: dev-ca
      mountPath: /etc/grid-security/certificates/dev-ca.pem
      subPath: dev-ca.pem
      readOnly: true
```

!!! note

    Files mounted with `subPath` are not updated when the ConfigMap or Secret changes; the pods need to be restarted.
    Mounting the whole volume as a directory (without `subPath`) picks up changes automatically after a short delay.

## From a PersistentVolume

Pods cannot reference a PersistentVolume directly: create a PersistentVolumeClaim bound to it and reference the claim.

```yaml
global:
  extraVolumes:
    - name: egi-trust-store
      persistentVolumeClaim:
        claimName: egi-trust-store
        readOnly: true
  extraVolumeMounts:
    - name: egi-trust-store
      mountPath: /etc/grid-security/certificates
      readOnly: true
```

Since many pods mount the same claim, possibly on different nodes, the claim needs the `ReadOnlyMany` or `ReadWriteMany` access mode (e.g. backed by NFS or CephFS).
This is a good fit for a trust store that is kept up to date centrally by an external process.

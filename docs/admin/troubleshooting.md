# Known issues

## external-dns

- The ingress loadBalancer resolves in multiple IPs: the `external-dns` service must be cleaned up from old entries in the DNS.

## ingress nginx

- pathType Prefix error: When deploying an ingress using nginx ingress controller using path: /.well-known on Rancher:
```
W0204 11:30:55.815720   50364 warnings.go:70] path /.well-known cannot be used with pathType Prefix
Error: INSTALLATION FAILED: failed to create resource: admission webhook "validate.nginx.ingress.kubernetes.io" denied the request: ingress contains invalid paths: path /.well-known cannot be used with pathType Prefix
```
Using a `implementationSpecific` path type can solve the issue. Otherwise apply directly on the nginx controller: 
```
set strict-validate-path-type: "false" for nginx
```

## rabbitmq

```
ERROR ==> Couldn't start RabbitMQ in background.
```
Set:
```
rabbitmq:
  podSecurityContext:
    enabled: true
  containerSecurityContext:
    enabled: true
```
# Rotate a Secret

DiracX requires various secrets to operate securely. This guide explains how to rotate these secrets for maintenance or security purposes.

Throughout this page you'll need the release name you used when installing with helm (typically `diracx`).
To find which releases are installed in your cluster you can use:

```bash
helm list
```

!!! note

    Many kubernetes distributions (e.g. openshift) provide a web interface for managing secrets which may be simpler than the raw kubernetes commands listed below.

## Database Secrets

### SQL Database Connection URLs

You can get the current connection URLs with:

```bash
$ kubectl get secret/diracx-sql-connection-urls -o jsonpath='{.data}' | jq -r 'to_entries[] | "\(.key): \(.value | @base64d)"'
DIRACX_DB_URL_AUTHDB: mysql+aiomysql://username:password@hostname.invalid:1234/DiracXAuthDB
DIRACX_DB_URL_JOBDB: mysql+aiomysql://username:password@hostname.invalid:1234/JobDB
```

You can then update the connection URLs using:

```bash
# One-liner to update
kubectl patch secret diracx-sql-connection-urls -p '{
  "data": {
    "DIRACX_DB_URL_AUTHDB": "'$(echo -n "mysql+aiomysql://username:newpassword@hostname.invalid:1234/DiracXAuthDB" | base64 -w0)'",
    "DIRACX_DB_URL_JOBDB": "'$(echo -n "mysql+aiomysql://username:newpassword@hostname.invalid:1234/JobDB" | base64 -w0)'"
  }
}'
# Restart services to use new connections
kubectl rollout restart deployment <release-name>
```

### Admin SQL Database Connection URLs

Similar to above, the root connection URLs can be found with:

```bash
$ kubectl get secret/diracx-sql-root-connection-urls -o jsonpath='{.data}' | jq -r 'to_entries[] | "\(.key): \(.value | @base64d)"'
DIRACX_DB_URL_AUTHDB: mysql+aiomysql://root:password@hostname.invalid:1234/DiracXAuthDB
DIRACX_DB_URL_JOBDB: mysql+aiomysql://root:password@hostname.invalid:1234/JobDB
```

And updated with:

```bash
# One-liner to update
kubectl patch secret diracx-sql-root-connection-urls -p '{
  "data": {
    "DIRACX_DB_URL_AUTHDB": "'$(echo -n "mysql+aiomysql://root:newpassword@hostname.invalid:1234/DiracXAuthDB" | base64 -w0)'",
    "DIRACX_DB_URL_JOBDB": "'$(echo -n "mysql+aiomysql://root:newpassword@hostname.invalid:1234/JobDB" | base64 -w0)'"
  }
}'
# No need to restart services as these URLs are only used during upgrades
```

### OpenSearch Connection Configuration

You can get the current connection configuration with:

```bash
$ kubectl get secret/diracx-os-connection-urls -o jsonpath='{.data}' | jq -r 'to_entries[] | "\(.key): \(.value | @base64d)"'
DIRACX_OS_DB_JOBPARAMETERSDB: {"hosts": "username:password@hostname.invalid:443/os", "use_ssl": true, "verify_certs": true}
```

You can then update the connection configuration using:

```bash
# One-liner to update
kubectl patch secret diracx-os-connection-urls -p '{
  "data": {
    "DIRACX_OS_DB_JOBPARAMETERSDB": "'$(echo -n '{"hosts": "username:newpassword@hostname.invalid:443/os", "use_ssl": true, "verify_certs": true}' | base64 -w0)'"
  }
}'
# Restart services to use new connections
kubectl rollout restart deployment <release-name>
```

## Object storage

### Sandbox store

!!! warning

    DiracX makes extensive use of pre-signed URLs for exposing access S3 to clients (e.g. when uploading/downloading sandboxes).
    These are explicitly tied to the access key and secret used by DiracX and revoking the credentials will cause errors for clients which have already been given pre-signed URLs.
    If the need is not urgent, we recommend waiting a few hours before revoking the previous credentials.

To check the current credentials:

```bash
$ kubectl get secret/diracx-secrets -o jsonpath='{.data.DIRACX_SANDBOX_STORE_S3_CLIENT_KWARGS}' | base64 -d
{"endpoint_url": "https://s3.invalid", "aws_access_key_id": "abcedfg", "aws_secret_access_key": "hijklmnop"}
```

To set new S3 credentials:

```bash
kubectl patch secret diracx-secrets -p '{
  "data": {
    "DIRACX_SANDBOX_STORE_S3_CLIENT_KWARGS": "'$(echo -n '{"endpoint_url": "https://s3.invalid", "aws_access_key_id": "123456", "aws_secret_access_key": "78910"}' | base64 -w0)'"
  }
}'
kubectl rollout restart deployment <release-name>
```

## Authentication Secrets

### DiracX Service Auth State Key

!!! warning

    Any currently in progress login sessions will fail as a result of changing the auth state key!

Update the authentication state key in-place (this will cause a brief service restart):

```bash
# Generate new key and update the existing secret
new_key=$(head -c 32 /dev/urandom | base64)
kubectl patch secret diracx-dynamic-secrets -p "{\"data\":{\"DIRACX_SERVICE_AUTH_STATE_KEY\":\"$new_key\"}}"

# Restart DiracX services to pick up the new key
kubectl rollout restart deployment <release-name>
```

### JWT Signing Keys (JWK)

DiracX supports having multiple JWT signing keys available at the same time, with only the latest one being used for signing new keys.

Before proceeding you likely want to know the key IDs that you currently have in use, you can find these by running:

```bash
$ curl --silent -L https://<your-installation-hostname>/.well-known/jwks.json | jq -r '.keys[]|.kid'
0196af4d311579728287cb89c24514e9
0196af4d0ab27b1299dff55b8617991d
```

To add a new JWK into rotation run:

```bash
# Get the current keystore
kubectl get secret/diracx-jwks -o jsonpath='{.data.jwks\.json}' | base64 -d > keystore.json
# Modify the keystore
python -m diracx.logic rotate-jwk --jwks-path keystore.json
# Update the secret in the cluster
kubectl patch secret/diracx-jwks --type='json' -p='[{"op": "replace", "path": "/data/jwks.json", "value":"'$(base64 -w 0 keystore.json)'"}]'
rm keystore.json
# Restart DiracX services to pick up the new key
kubectl rollout restart deployment <release-name>
```

After your satisfied the previous key is no longer used (or if you wish to immediately revoke all currently active credentials) you can run:

```bash
# Get the current keystore
kubectl get secret/diracx-jwks -o jsonpath='{.data.jwks\.json}' | base64 -d > keystore.json
# Modify the keystore
python -m diracx.logic delete-jwk --jwks-path keystore.json --kid 0196af4d0ab27b1299dff55b8617991d
# Update the secret in the cluster
kubectl patch secret/diracx-jwks --type='json' -p='[{"op": "replace", "path": "/data/jwks.json", "value":"'$(base64 -w 0 keystore.json)'"}]'
rm keystore.json
# Restart DiracX services to pick up the new key
kubectl rollout restart deployment <release-name>
```

### Legacy exchange secret

!!! warning

    Rotating the legacy exchange secret will cause a brief service interruption. In principle clients should automatically retry but good luck!

To rotate the secret which is used by your legacy DIRAC installation to communicate with DiracX first generate a new pair of secrets:

```python
import secrets
import base64
import hashlib

token = secrets.token_bytes()

# This is the secret to include in the request by setting the
# /DiracX/LegacyExchangeApiKey CS option in your legacy DIRAC installation
print(f"API key is diracx:legacy:{base64.urlsafe_b64encode(token).decode()}")

# This is the environment variable to set on the DiracX server
print(
    f"DIRACX_LEGACY_EXCHANGE_HASHED_API_KEY={hashlib.sha256(token).hexdigest()}"
)
```

Update the hashed secret in your DiracX installation:

```bash
kubectl patch secret diracx-secrets -p '{
  "data": {
    "DIRACX_LEGACY_EXCHANGE_HASHED_API_KEY": "'$(echo -n "0123456789abcef0123456789abcef0123456789abcef0123456789abcef0123" | base64 -w0)'"
  }
}'
```

Then update `/DiracX/LegacyExchangeApiKey` in your legacy DIRAC installation's `dirac.cfg` and restart:

```bash
# Trigger a rollout of DiracX to pick up the new key
kubectl rollout restart deployment <release-name>
# Restart your legacy DIRAC services (e.g. with "runsvctrl t ...")
```

## TLS Certificates

TLS certificates are automatically managed by cert-manager and shouldn't require intervention.
To force certificate renewal see the [upstream documentation](https://cert-manager.io/docs/reference/cmctl/#renew).

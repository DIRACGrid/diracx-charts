# CERN SSO Configuration

This document describes how to configure CERN SSO as an Identity Provider (IdP) for DiracX.

## Prerequisites

- Access to CERN Application Portal
- Administrative rights to register a new application

## Registration Steps

1. Go to the [CERN Application Portal](https://application-portal.web.cern.ch/)
2. Click "Register a new application"
3. Fill in the application details:
   - **Application Name**: DiracX [Your VO/Installation]
   - **Description**: DiracX authentication for [Your VO]
   - **SSO Protocol**: OpenID Connect

## Configuration

### Redirect URLs

Configure the following redirect URLs in your CERN SSO application:

```
https://<youdiracx.invalid>/api/auth/device/complete
https://<youdiracx.invalid>/api/auth/authorize/complete
```

Replace `<youdiracx.invalid>` with your actual DiracX hostname.

### Client Configuration

- **Client Type**: Public (no client authentication required)
- **Required Scopes**: `email`, `openid`, `profile`
- **Grant Type**: Authorization Code Flow with PKCE
- **Token Endpoint Authentication**: None (public client)

## Integration with DiracX

Once your CERN SSO application is registered, you'll receive:
- Client ID
- Discovery URL (usually `https://auth.cern.ch/auth/realms/cern/.well-known/openid_configuration`)

Configure these in your DiracX values:

```yaml
diracx:
  settings:
    DIRACX_AUTH_OIDC_PROVIDER_NAME: "cern"
    DIRACX_AUTH_OIDC_CLIENT_ID: "your-client-id"
    DIRACX_AUTH_OIDC_DISCOVERY_URL: "https://auth.cern.ch/auth/realms/cern/.well-known/openid_configuration"
```

## User Registration

Note that users still need to be registered in DiracX by configuring the `CsSync` section in the Configuration Service (CS).

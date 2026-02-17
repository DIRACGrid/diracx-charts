# Chart Structure

The DiracX Helm chart is designed to deploy a complete DiracX environment with all necessary dependencies and services. This document explains the structure, components, and initialization process of the chart.

## Overview

The DiracX chart is an umbrella chart that orchestrates the deployment of:

- **DiracX services**: The core DiracX API and CLI components
- **DiracX Web**: The web frontend application
- **External dependencies**: Databases, message queues, search engines, and observability tools
- **Authentication services**: Identity providers and certificate management
- **Initialization jobs**: Bootstrap processes for databases, secrets, and configuration

The structure is heavily inspired by the one provided for GitLab due to their similar use case of providing a generic helm chart for a wide variety of installations.
Detailed documentation with justification for technical decisions can be found [here](https://docs.gitlab.com/charts/).

![DiracX architecture](https://diracx-docs-static.s3.cern.ch/assets/images/admin/explanations/architecture_diragram.png)

## Chart Dependencies

The chart includes the following external dependencies, all conditionally enabled:

!!! warning "Production Deployments"
    The bundled dependencies listed below are primarily intended for development and testing environments. For production deployments, you should use externally managed services. See the [installation guide](../how-to/install/installing.md) for production deployment recommendations.

### Core Infrastructure
- **MySQL** (`mysql`): Primary database for DiracX data storage
- **RabbitMQ** (`rabbitmq`): Message queue for asynchronous task processing
- **OpenSearch/Elasticsearch**: Search and indexing capabilities
  - `opensearch` (preferred): Open source search engine
  - `elasticsearch`: Alternative search engine option

### Storage
- **MinIO** (`minio`): S3-compatible object storage for files and artifacts

### Authentication & Security
- **Dex** (`dex`): OpenID Connect identity provider for authentication
- **cert-manager** (`cert-manager`): Automated TLS certificate management
- **cert-manager-issuer**: Custom issuer configuration for cert-manager

### Observability
- **OpenTelemetry Collector** (`opentelemetry-collector`): Telemetry data collection and processing
- **Jaeger** (`jaeger`): Distributed tracing system
- **Grafana** (`grafana`): Metrics visualization and dashboards
- **Prometheus** (`prometheus`): Metrics collection and alerting

## Main Components

### DiracX Services
The core DiracX deployment consists of:

- **Main Deployment** (`diracx/deployment.yaml`): API server pods running DiracX services
- **CLI Deployment** (`diracx/deployment-cli.yaml`): Command-line interface pods for administrative tasks
- **Service** (`diracx/service.yaml`): Kubernetes service exposing DiracX APIs
- **ServiceAccount** (`diracx/serviceaccount.yaml`): Service account with necessary permissions

### DiracX Web
The web frontend deployment includes:

- **Deployment** (`diracx-web/deployment.yaml`): Web application pods serving the DiracX UI
- **Service** (`diracx-web/service.yaml`): Service exposing the web interface

### Configuration and Secrets
- **Secrets** (`diracx/secrets.yaml`): Kubernetes secrets for sensitive configuration
- **Environment Config** (`envconfig.yaml`): Environment-specific configuration
- **Ingress** (`ingress.yaml`): HTTP/HTTPS routing configuration

## Initialization Process

The chart uses a series of initialization jobs to bootstrap the DiracX environment. These jobs run as Kubernetes Jobs before the main services start:

### 1. Secret Initialization (`init-secrets/`)
- **Purpose**: Generates and manages cryptographic secrets and keys
- **Components**:
  - ConfigMap with initialization script
  - Job that creates necessary secrets
  - RBAC configuration for secret management
- **When it runs**: First, before all other initialization jobs

### 2. SQL Database Initialization (`init-sql/`)
- **Purpose**: Sets up database schema and initial data
- **Components**:
  - ConfigMap with SQL initialization scripts
  - Job that connects to MySQL and creates/updates schemas
- **When it runs**: After secret initialization, before application startup. See [the explanation on how databases are handled](database-management.md) for more details.

### 3. OpenSearch Initialization (`init-os/`)
- **Purpose**: Configures OpenSearch indices and mappings
- **Components**:
  - ConfigMap with OpenSearch setup scripts
  - Job that creates necessary indices
- **When it runs**: After secret initialization, parallel to SQL initialization

### 4. Configuration Store Initialization (`init-cs/`)
- **Purpose**: Initializes the DiracX Configuration Store with default settings
- **Components**:
  - ConfigMap with CS initialization scripts
  - Job that populates initial configuration
- **When it runs**: After database and OpenSearch are ready

### 5. Keystore Initialization (`init-keystore/`)
- **Purpose**: Sets up cryptographic keystores and certificates for signing JWTs
- **Components**:
  - ConfigMap with keystore management scripts
  - Job that generates and loads certificates
- **When it runs**: After secret initialization, before services start

## Secret Management

DiracX uses multiple types of secrets for secure operation.
The chart automatically generates and manages these secrets through the initialization process.
To later update the values of these secrets see the [rotate a secret documentation](../how-to/rotate-a-secret.md).

### Types of Secrets

#### Application Secrets (`diracx-secrets`)
- **DiracX configuration**: Contains all DiracX service settings and configuration values
- **Generated from**: `values.yaml` configuration under `diracx.settings`
- **Usage**: Mounted as environment variables in DiracX service pods

#### Dynamic Secrets (`diracx-dynamic-secrets`)
- **DIRACX_SERVICE_AUTH_STATE_KEY**: 32-byte base64-encoded key for OAuth state management
- **Generated**: Automatically during secret initialization
- **Usage**: Secure token exchange in authentication flows

#### Database Connection Secrets
- **diracx-sql-connection-urls**: Database connection strings for DiracX services
- **diracx-sql-root-connection-urls**: Administrative database connection strings for applying schema changes
- **Format**: MySQL connection URLs with embedded credentials
- **Generated for each database**: AuthDB, JobDB, JobLoggingDB, PilotAgentsDB, SandBoxMetadataDB, TaskQueueDB

#### Search Engine Connection Secrets
- **diracx-os-connection-urls**: OpenSearch/Elasticsearch connection configurations
- **diracx-os-root-connection-urls**: Administrative search engine connections
- **Format**: JSON configuration with hosts, authentication, and SSL settings
- **Generated for each index**: JobParametersDB

#### External Service Secrets
When using bundled dependencies, the chart generates:
- **mysql-secret**: MySQL database passwords (root, replication, application user)
- **rabbitmq-secret**: RabbitMQ credentials (password, Erlang cookie)

#### Certificate and Keystore Secrets
- **Keystore secrets**: Generated by `init-keystore` job for JWT signing
- **TLS certificates**: Managed by cert-manager for HTTPS endpoints
- **CA certificates**: For internal service communication

### Secret Generation Process

1. **Automatic Generation**: Secrets are created if they don't exist during deployment
2. **Preservation**: Existing secrets are preserved during upgrades
3. **Validation**: Missing keys in existing secrets are automatically added
4. **Encoding**: Sensitive values are base64-encoded when stored in Kubernetes

### Secret Access Patterns

- **Environment Variables**: Configuration secrets are injected as environment variables
- **Volume Mounts**: Certificate secrets are mounted as files in containers

## Storage Volumes

The chart creates several persistent volumes:

- **CS Store Volume** (`diracx/cs-store-volume.yml`): Persistent storage for Configuration Store data (development only)
- **DiracX Code Volume** (`diracx-code-volume.yml`): Volume for DiracX application code (used in development mode)

## Configuration Structure

To see the complete set of available values, refer to [the values reference](../reference/values.md).

### Global Configuration

The `global` section in `values.yaml` contains shared settings:

```yaml
global:
  batchJobTTL: 600                    # Job retention time
  imagePullPolicy: Always             # Container image pull policy
  storageClassName: standard          # Kubernetes storage class
  activeDeadlineSeconds: 900          # Job timeout
  images:                             # Container image specifications
    tag: "dev"
    services: ghcr.io/diracgrid/diracx/services
    client: ghcr.io/diracgrid/diracx/client
    web:
      tag: "dev"
      repository: ghcr.io/diracgrid/diracx-web/static
```

It is also possible to separately configure image registries for different components. Each image used in the chart is associated with a `registryType` value (`ghcr` or `dockerhub`), which is then mapped to a registry URL defined in the `global.images` section.

`busybox` and `web` images do not use the same tag as the main services, so they have their own `tag` fields in separate sub-sections of the `values.yaml` file.

For example:


```yaml
global:
  batchJobTTL: 600                    # Job retention time
  imagePullPolicy: Always             # Container image pull policy
  storageClassName: standard          # Kubernetes storage class
  activeDeadlineSeconds: 900          # Job timeout
  images:                             # Container image specifications
    tag: "dev"
    ghcr_registry: ghcr.io
    dockerhub_registry: docker.io
    services: diracgrid/diracx/services
    client: diracgrid/diracx/client
    busybox:
      tag: "latest"
      repository: "busybox"
      registryType: dockerhub
    web:
      tag: "dev"
      repository: diracgrid/diracx-web/static
      registryType: ghcr
```

In this case `global.images.services` should not include the registry prefix; the chart templates will prepend the appropriate registry URL based on the specified `registryType`.

Dependency charts are not affected by these settings since they have their own image configuration, controlled by their respective values.

### Component Configuration
Each component can be configured independently:

- **Replica counts**: Separate settings for DiracX services and web frontend
- **Initialization jobs**: Enable/disable specific initialization steps
- **Developer mode**: Special configuration for development environments
- **Dependencies**: Each external dependency can be enabled/disabled and configured

## Development vs Production Modes

### Development Mode

When `developer.enabled: true`:

- Mounts local source code for live development
- Configures special URLs for local testing
- Uses development image tags

To find more about running in development mode see [here](../../dev/tutorials/run-locally.md).

### Production Mode

For production deployments:

- Uses stable image tags
- Enables all security features
- Configures proper resource limits and requests
- Sets up monitoring and alerting

To find more about running in production mode see [here](../how-to/install/installing.md).

## Bootstrap Sequence

The complete bootstrap sequence follows this order:

1. **Helm Dependencies**: External charts are deployed (MySQL, RabbitMQ, etc.)
2. **Secret Generation**: `init-secrets` job creates cryptographic materials
3. **Database Setup**: `init-sql` job initializes database schemas
4. **Search Setup**: `init-os` job configures OpenSearch indices
5. **Configuration**: `init-cs` job populates Configuration Store
6. **Certificate Setup**: `init-keystore` job manages certificates
7. **Service Startup**: DiracX services and web frontend start
8. **Health Checks**: Services perform readiness and liveness checks

This staged approach ensures that all dependencies are ready before DiracX services attempt to start, providing a reliable deployment process.

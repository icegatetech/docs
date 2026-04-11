---
title: Installation
description: Install IceGate on Kubernetes with Helm
---

# Installation

IceGate is deployed on Kubernetes using Helm charts, with Kustomize overlays for environment-specific customizations.

## Prerequisites

- **Kubernetes** >= 1.28 with **Helm 3**
- **Object Storage:** AWS S3 or S3-compatible (MinIO)
- **Iceberg Catalog:** Nessie (REST), AWS S3 Tables, or AWS Glue

## Helm Chart

The Helm chart deploys all IceGate components: Ingest, Query, and a Migrate job (schema creation as a pre-install/pre-upgrade hook).

### Install from OCI Registry

```bash
helm install icegate oci://ghcr.io/icegatetech/charts/icegate \
  --version 0.1.0 \
  --namespace icegate \
  --create-namespace \
  -f values.yaml
```

### Install from Local Charts

```bash
git clone https://github.com/icegatetech/icegate.git
helm install icegate ./icegate/config/helm/icegate \
  --namespace icegate \
  --create-namespace \
  -f values.yaml
```

### Minimal values.yaml

A minimal `values.yaml` for a REST catalog (Nessie) with S3-compatible storage:

```yaml
catalog:
  backend: rest
  rest:
    uri: http://nessie:19120/iceberg
  warehouse: "s3://warehouse/"

storage:
  s3:
    bucket: warehouse
    region: us-east-1
    endpoint: "http://minio:9000"

queue:
  common:
    basePath: "s3://queue/"

aws:
  existingSecret: icegate-aws-credentials
  region: us-east-1
```

### AWS Glue Catalog

```yaml
catalog:
  backend: glue
  glue:
    catalogId: "123456789012"
  warehouse: "s3://my-bucket/warehouse/"

storage:
  s3:
    bucket: my-bucket
    region: eu-central-1

aws:
  existingSecret: icegate-aws-credentials
  region: eu-central-1
```

### AWS S3 Tables Catalog

```yaml
catalog:
  backend: s3tables
  s3tables:
    tableBucketArn: "arn:aws:s3tables:eu-central-1:123456789012:bucket/my-tables"

storage:
  s3:
    region: eu-central-1

aws:
  existingSecret: icegate-aws-credentials
  region: eu-central-1
```

### Key Helm Values

| Value | Default | Description |
|-------|---------|-------------|
| `catalog.backend` | `rest` | Catalog type: `rest`, `s3tables`, or `glue` |
| `storage.s3.bucket` | `warehouse` | S3 bucket name |
| `storage.s3.endpoint` | `""` | Custom S3 endpoint (MinIO). Omit for real AWS S3 |
| `aws.existingSecret` | `""` | Secret with `aws-access-key-id` and `aws-secret-access-key` keys |
| `query.replicaCount` | `1` | Query service replicas |
| `ingest.replicaCount` | `1` | Ingest service replicas |
| `query.cache.enabled` | `true` | Enable hybrid disk+memory cache for query reads |
| `query.engine.walQueryEnabled` | `false` | Include WAL data in query results for real-time access |
| `serviceMonitor.enabled` | `false` | Create Prometheus ServiceMonitor resources |
| `migrate.enabled` | `true` | Run schema migration as Helm hook |

### Container Images

| Component | Image |
|-----------|-------|
| Query | `ghcr.io/icegatetech/icegate-query` |
| Ingest | `ghcr.io/icegatetech/icegate-ingest` |
| Migrate | `ghcr.io/icegatetech/icegate-maintain` |

## Kustomize Overlays

For environment-specific customizations, IceGate provides Kustomize overlays that compose the Helm chart with infrastructure dependencies.

### Available Overlays

| Overlay | Description | Infrastructure |
|---------|-------------|----------------|
| `skaffold` | Local development with Skaffold | MinIO, Nessie, observability stack |
| `orbstack` | OrbStack container runtime | MinIO, Nessie, observability stack |
| `aws-glue` | AWS Glue catalog | Observability stack (no MinIO/Nessie) |
| `aws-s3tables` | AWS S3 Tables catalog | Observability stack (no MinIO/Nessie) |
| `external-s3` | External S3 + Nessie catalog | Nessie, observability stack (no MinIO) |

All overlays share a common base (`config/kustomize/base/`) that deploys the observability stack: Prometheus (kube-prometheus-stack), Grafana with pre-built IceGate dashboards, and Jaeger for distributed tracing.

### Usage

```bash
# Apply an overlay directly
kubectl apply -k config/kustomize/overlays/aws-glue

# Or use Skaffold for development (see Development Setup)
skaffold dev
```

### Customizing an Overlay

Each overlay contains:

- `kustomization.yaml` — declares Helm charts and patches
- `values-icegate.yaml` — IceGate Helm values for this environment
- `secret-aws.yaml` — AWS credentials Secret (edit before applying)

To create a custom overlay:

```bash
cp -r config/kustomize/overlays/orbstack config/kustomize/overlays/my-env
vi config/kustomize/overlays/my-env/values-icegate.yaml
vi config/kustomize/overlays/my-env/secret-aws.yaml
kubectl apply -k config/kustomize/overlays/my-env
```

## Verify Installation

```bash
# Check pods are running
kubectl get pods -n icegate

# Port-forward to query service
kubectl port-forward -n icegate svc/icegate-query 3100:3100

# Test readiness
curl http://localhost:3100/ready
```

## Next Steps

- Continue to [Quick Start](quickstart.md) to ingest your first data
- See [Configuration](configuration.md) for detailed configuration options
- Set up a [Development Environment](../development/setup.md) for contributing

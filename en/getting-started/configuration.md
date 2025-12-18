---
title: Configuration
description: Configure IceGate components
---

# Configuration

IceGate uses YAML configuration files to configure its components. This guide covers the main configuration options.

## Configuration File Structure

IceGate components can be configured via YAML files or environment variables.

### Query Service Configuration

```yaml
# query.yaml
loki:
  enabled: true
  host: "0.0.0.0"
  port: 3100

prometheus:
  enabled: true
  host: "0.0.0.0"
  port: 9090

tempo:
  enabled: true
  host: "0.0.0.0"
  port: 3200

engine:
  catalog:
    type: rest
    uri: "http://localhost:19120/api/v1"
    warehouse: "s3://warehouse/"
  storage:
    type: s3
    bucket: warehouse
    endpoint: "http://localhost:9000"
    region: us-east-1
```

### Ingest Service Configuration

```yaml
# ingest.yaml
otlp_http:
  enabled: true
  host: "0.0.0.0"
  port: 4318

otlp_grpc:
  enabled: true
  host: "0.0.0.0"
  port: 4317

storage:
  type: s3
  bucket: warehouse
  endpoint: "http://localhost:9000"
  region: us-east-1
```

## Environment Variables

Configuration can also be set via environment variables:

| Variable | Description | Default |
|----------|-------------|---------|
| `AWS_ACCESS_KEY_ID` | S3 access key | - |
| `AWS_SECRET_ACCESS_KEY` | S3 secret key | - |
| `AWS_REGION` | S3 region | `us-east-1` |
| `ICEGATE_LOKI_PORT` | Loki API port | `3100` |
| `ICEGATE_PROMETHEUS_PORT` | Prometheus API port | `9090` |
| `ICEGATE_TEMPO_PORT` | Tempo API port | `3200` |

## Storage Configuration

### S3-Compatible Storage

IceGate stores all data in S3-compatible object storage (AWS S3, MinIO, etc.):

```yaml
storage:
  type: s3
  bucket: warehouse
  endpoint: "http://localhost:9000"  # For MinIO
  region: us-east-1
  force_path_style: true  # Required for MinIO
```

### Catalog Configuration

IceGate uses Apache Iceberg for the catalog. Supported catalog types:

#### REST Catalog (Nessie)

```yaml
catalog:
  type: rest
  uri: "http://localhost:19120/api/v1"
  warehouse: "s3://warehouse/"
```

## Development Environment

For local development, use the provided Docker Compose configuration:

```bash
# Start with hot-reload
make dev

# Start without query service (for debugging)
make debug
```

Environment variables for local development:

```bash
export AWS_ACCESS_KEY_ID=minioadmin
export AWS_SECRET_ACCESS_KEY=minioadmin
export AWS_REGION=us-east-1
```

## Next Steps

- Learn about [Data Ingestion](../guides/ingestion.md)
- Explore [Querying](../guides/querying.md) capabilities
- Set up [Multi-Tenancy](../guides/multi-tenancy.md)

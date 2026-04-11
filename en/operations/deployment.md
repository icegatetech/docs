---
title: Deployment
description: Deploy IceGate in production environments
---

# Deployment

This guide covers deploying IceGate in production environments.

## Prerequisites

- **Object Storage:** S3, MinIO, or S3-compatible storage
- **Iceberg Catalog:** Nessie (REST), AWS S3 Tables, or AWS Glue
- **Docker/Kubernetes:** For container orchestration

## Architecture Considerations

### Component Scaling

| Component | Scaling | Notes |
|-----------|---------|-------|
| Ingest | Horizontal | Scale for write throughput |
| Query | Horizontal | Scale for query concurrency |
| Maintain | Single leader | Coordinates compaction |

### Resource Requirements

**Ingest Service (per replica):**

- CPU: 2-4 cores
- Memory: 4-8 GB
- Disk: Minimal (writes to object storage)

**Query Service (per replica):**

- CPU: 4-8 cores
- Memory: 8-32 GB (depends on query complexity)
- Disk: SSD recommended for cache (`catalog.cache.disk_dir`)

**Maintain Service:**

- CPU: 2-4 cores
- Memory: 4-8 GB
- Disk: SSD for compaction temp files

## Docker Compose Deployment

### Docker Compose Profiles

The project includes Docker Compose profiles for different deployment scenarios:

```bash
# Core services: MinIO, Nessie, Ingest, Query, Maintain
make run-core-release

# Core + load generator for testing
make run-load-release

# Core + monitoring (Jaeger, Prometheus, Grafana)
# Core + analytics (Trino)
make run-analytics-release
```

### Production Setup

```yaml
# docker-compose.yml
services:
  minio:
    image: minio/minio:latest
    command: server /data --console-address ":9001"
    environment:
      MINIO_ROOT_USER: ${S3_ACCESS_KEY}
      MINIO_ROOT_PASSWORD: ${S3_SECRET_KEY}
    volumes:
      - minio-data:/data
    ports:
      - "9000:9000"
      - "9001:9001"

  nessie:
    image: projectnessie/nessie:latest
    environment:
      NESSIE_VERSION_STORE_TYPE: ROCKSDB
    volumes:
      - nessie-data:/data
    ports:
      - "19120:19120"

  ingest:
    image: icegate/ingest:latest
    command: run -c /etc/icegate/ingest.yaml
    environment:
      AWS_ACCESS_KEY_ID: ${S3_ACCESS_KEY}
      AWS_SECRET_ACCESS_KEY: ${S3_SECRET_KEY}
    volumes:
      - ./config/ingest.yaml:/etc/icegate/ingest.yaml:ro
    ports:
      - "4317:4317"   # OTLP gRPC
      - "4318:4318"   # OTLP HTTP
      - "9091:9091"   # Prometheus metrics
    depends_on:
      - minio
      - nessie

  query:
    image: icegate/query:latest
    command: run -c /etc/icegate/query.yaml
    environment:
      AWS_ACCESS_KEY_ID: ${S3_ACCESS_KEY}
      AWS_SECRET_ACCESS_KEY: ${S3_SECRET_KEY}
    volumes:
      - ./config/query.yaml:/etc/icegate/query.yaml:ro
      - query-cache:/tmp/icegate/cache
    ports:
      - "3100:3100"   # Loki API
      - "9090:9090"   # Prometheus API
      - "3200:3200"   # Tempo API
    depends_on:
      - minio
      - nessie

  maintain:
    image: icegate/maintain:latest
    environment:
      AWS_ACCESS_KEY_ID: ${S3_ACCESS_KEY}
      AWS_SECRET_ACCESS_KEY: ${S3_SECRET_KEY}
    volumes:
      - ./config/maintain.yaml:/etc/icegate/maintain.yaml:ro
    depends_on:
      - minio
      - nessie

volumes:
  minio-data:
  nessie-data:
  query-cache:
```

### Docker Build

Build container images from source:

```bash
# Build ingest service (release mode)
docker build -t icegate/ingest:latest \
  --build-arg BINARY=ingest \
  --build-arg PROFILE=release \
  -f config/docker/Dockerfile .

# Build query service
docker build -t icegate/query:latest \
  --build-arg BINARY=query \
  --build-arg PROFILE=release \
  -f config/docker/Dockerfile .

# Build maintain service
docker build -t icegate/maintain:latest \
  --build-arg BINARY=maintain \
  --build-arg PROFILE=release \
  -f config/docker/Dockerfile .
```

## Kubernetes Deployment

### Helm Charts

IceGate includes Helm charts for Kubernetes deployment:

```bash
# Install from local charts
helm install icegate ./config/helm/icegate

# With custom values
helm install icegate ./config/helm/icegate \
  -f my-values.yaml \
  --set storage.bucket=my-warehouse
```

### Kustomize Overlays

Pre-built Kustomize overlays are available for common scenarios:

| Overlay | Description |
|---------|-------------|
| `skaffold` | Local development with Skaffold |
| `orbstack` | OrbStack container runtime |
| `aws-glue` | AWS Glue catalog integration |
| `aws-s3tables` | AWS S3 Tables catalog integration |
| `external-s3` | External S3 storage (not MinIO) |

```bash
# Apply with kustomize
kubectl apply -k config/kustomize/overlays/aws-glue
```

## S3 Storage Configuration

### AWS S3

```yaml
storage:
  backend: !s3
    bucket: icegate-warehouse
    region: us-east-1
```

### MinIO

```yaml
storage:
  backend: !s3
    bucket: warehouse
    endpoint: http://minio:9000
    region: us-east-1
```

## Fault Tolerance and High Availability

### Failure Modes

{{product_name}} is designed for resilience through stateless compute and durable object storage:

| Component | Failure Impact | Recovery |
|-----------|---------------|----------|
| Ingest replica fails | Reduced write throughput | Kubernetes restarts pod; other replicas continue ingesting |
| Query replica fails | Reduced query capacity | Load balancer routes to healthy replicas |
| Maintain/Shift | WAL segments accumulate | Restarts and resumes from last committed snapshot |
| Object storage (S3) | Service outage | WAL writes fail with 503; clients should retry |
| Catalog (Nessie) | Cannot commit new data or read metadata | Queries fail; data in WAL is preserved |

### Durability Guarantees

- **WAL persistence**: All ingested data is written to object storage (S3/MinIO) before acknowledgment. Data survives node failures.
- **Exactly-once delivery**: The ingest service acknowledges only after WAL write completes.
- **Immutable segments**: WAL segments are append-only Parquet files. Once written, they cannot be corrupted by subsequent operations.
- **Iceberg snapshots**: Each shift operation creates an atomic Iceberg snapshot. Failed shifts do not corrupt existing data.

### Stateless Query Service

The Query service has no local state — it reads from object storage and the Iceberg catalog. Any number of replicas can be started and stopped without coordination:

```yaml
# Helm values.yaml — scale query for HA
query:
  replicaCount: 3
  resources:
    requests:
      cpu: "4"
      memory: 8Gi
    limits:
      cpu: "8"
      memory: 16Gi
```

### Multi-Zone Deployment

Deploy services across availability zones for zone failure resilience:

```yaml
# Helm values.yaml
query:
  replicaCount: 3
  affinity:
    podAntiAffinity:
      preferredDuringSchedulingIgnoredDuringExecution:
        - weight: 100
          podAffinityTerm:
            labelSelector:
              matchExpressions:
                - key: app.kubernetes.io/component
                  operator: In
                  values: ["query"]
            topologyKey: topology.kubernetes.io/zone

ingest:
  replicaCount: 2
  affinity:
    podAntiAffinity:
      preferredDuringSchedulingIgnoredDuringExecution:
        - weight: 100
          podAffinityTerm:
            labelSelector:
              matchExpressions:
                - key: app.kubernetes.io/component
                  operator: In
                  values: ["ingest"]
            topologyKey: topology.kubernetes.io/zone
```

### Health Checks

All services expose health endpoints for load balancer integration:

| Service | Endpoint | Port | Use |
|---------|----------|------|-----|
| Ingest | `GET /health` | 4318 | Readiness/liveness probe |
| Query (Loki) | `GET /ready` | 3100 | Readiness/liveness probe |
| Query (Tempo) | `GET /ready` | 3200 | Readiness/liveness probe |
| Query (Prometheus) | `GET /-/ready` | 9090 | Readiness/liveness probe |

Kubernetes probe configuration:

```yaml
# Included in Helm chart by default
livenessProbe:
  httpGet:
    path: /ready
    port: 3100
  initialDelaySeconds: 10
  periodSeconds: 15
readinessProbe:
  httpGet:
    path: /ready
    port: 3100
  initialDelaySeconds: 5
  periodSeconds: 5
```

## Monitoring

### Metrics

IceGate services expose Prometheus metrics on a dedicated port (default: 9091):

- Ingest metrics: `http://ingest:9091/metrics`
- Query metrics: `http://query:9091/metrics`

Configure in each service:

```yaml
metrics:
  enabled: true
  host: 0.0.0.0
  port: 9091
  path: /metrics
```

### Self-Observability with Tracing

IceGate can export its own traces via OTLP for debugging:

```yaml
tracing:
  enabled: true
  service_name: icegate-query
  otlp_endpoint: http://jaeger:4317
  sample_ratio: 0.1  # 10% sampling in production
```

### Logging

Services log to stdout. Configure log level via `RUST_LOG` environment variable:

```yaml
environment:
  RUST_LOG: "info,icegate_query=debug"
```

## Security

### Network Security

- Use TLS for all external connections
- Restrict access to MinIO/Nessie from internal network only
- Use network policies in Kubernetes

### Authentication

Configure tenant authentication via reverse proxy or API gateway:

```nginx
location /loki/ {
    auth_request /auth;
    proxy_set_header X-Scope-OrgID $remote_user;
    proxy_pass http://query:3100/;
}
```

## Next Steps

- Configure [Maintenance](maintenance.md) operations
- Set up [Troubleshooting](troubleshooting.md) procedures
- Review [Architecture](../architecture/overview.md) for scaling decisions

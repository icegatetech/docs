---
title: Deployment
description: Deploy IceGate in production environments
---

# Deployment

This guide covers deploying IceGate in production environments.

## Prerequisites

- **Object Storage:** S3, MinIO, or S3-compatible storage
- **Iceberg Catalog:** Nessie, AWS Glue, or other Iceberg REST catalog
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
- Disk: SSD for temp files (optional)

**Maintain Service:**

- CPU: 2-4 cores
- Memory: 4-8 GB
- Disk: SSD for compaction temp files

## Docker Compose Deployment

### Basic Production Setup

```yaml
# docker-compose.yml
version: '3.8'

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
    environment:
      AWS_ACCESS_KEY_ID: ${S3_ACCESS_KEY}
      AWS_SECRET_ACCESS_KEY: ${S3_SECRET_KEY}
      AWS_REGION: us-east-1
    ports:
      - "4317:4317"
      - "4318:4318"
    depends_on:
      - minio
      - nessie

  query:
    image: icegate/query:latest
    environment:
      AWS_ACCESS_KEY_ID: ${S3_ACCESS_KEY}
      AWS_SECRET_ACCESS_KEY: ${S3_SECRET_KEY}
      AWS_REGION: us-east-1
    ports:
      - "3100:3100"
      - "9090:9090"
      - "3200:3200"
    depends_on:
      - minio
      - nessie

  maintain:
    image: icegate/maintain:latest
    environment:
      AWS_ACCESS_KEY_ID: ${S3_ACCESS_KEY}
      AWS_SECRET_ACCESS_KEY: ${S3_SECRET_KEY}
      AWS_REGION: us-east-1
    depends_on:
      - minio
      - nessie

volumes:
  minio-data:
  nessie-data:
```

## S3 Storage Configuration

### AWS S3

```yaml
storage:
  type: s3
  bucket: icegate-warehouse
  region: us-east-1
```

### MinIO

```yaml
storage:
  type: s3
  bucket: warehouse
  endpoint: http://minio:9000
  region: us-east-1
  force_path_style: true
```

## Documentation Hosting

IceGate documentation is built with Diplodoc and can be deployed to S3/MinIO.

### Build Documentation

```bash
cd docs
npm install
npm run build
```

### Deploy to S3

```bash
# Sync to S3 bucket
aws s3 sync ./build s3://docs-bucket/icegate/ \
  --delete \
  --cache-control "max-age=3600"

# For MinIO
mc cp --recursive ./build/ minio/docs-bucket/icegate/
```

### S3 Static Website Configuration

Enable static website hosting on your S3 bucket:

```json
{
  "IndexDocument": {"Suffix": "index.html"},
  "ErrorDocument": {"Key": "404.html"}
}
```

## High Availability

### Multi-Zone Deployment

Deploy services across multiple availability zones:

```yaml
services:
  query:
    deploy:
      replicas: 3
      placement:
        constraints:
          - node.labels.zone != ${ZONE}
```

### Health Checks

All services expose health endpoints:

- Ingest: `GET /health`
- Query: `GET /ready`
- Maintain: `GET /health`

## Monitoring

### Metrics

IceGate services expose Prometheus metrics:

- Query: `http://query:9090/metrics`
- Ingest: `http://ingest:9090/metrics`

### Logging

Services log to stdout in JSON format. Configure log aggregation:

```yaml
logging:
  driver: json-file
  options:
    max-size: "100m"
    max-file: "3"
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

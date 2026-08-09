---
title: Configuration
description: Full configuration reference for {{product_name}} - CLI usage, environment variables, catalog and storage backends, and per-service ingest and query options.
---

# Configuration

{{product_name}} uses YAML or TOML configuration files. The format is auto-detected by file extension (`.yaml`/`.yml` for YAML, `.toml` for TOML).

## CLI Usage

Each binary accepts a configuration file via the `-c` / `--config` flag:

```bash
# Ingest service
ingest run -c /etc/icegate/ingest.yaml

# Query service
query run -c /etc/icegate/query.yaml

# Maintain service (schema migration)
maintain migrate create -c /etc/icegate/maintain.yaml
maintain migrate upgrade -c /etc/icegate/maintain.yaml

# Show version
ingest version
query version
```

## Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `AWS_ACCESS_KEY_ID` | S3 access key (used by storage and job manager) | |
| `AWS_SECRET_ACCESS_KEY` | S3 secret key | |
| `OTEL_EXPORTER_OTLP_ENDPOINT` | OpenTelemetry tracing endpoint (fallback if `tracing.otlp_endpoint` not set) | |
| `RUST_LOG` | Log level filter (e.g., `info`, `debug`, `info,icegate_query=debug`) | `info` |

## Catalog Configuration

The `catalog` section configures the Apache Iceberg catalog. It is shared by all services (Ingest, Query, Maintain).

```yaml
catalog:
  backend: !s3
    warehouse: catalog
  warehouse: s3://warehouse/
  properties:
    bucket: warehouse
    region: us-east-1
    endpoint: http://rustfs:9000
```

### Catalog Parameters

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `backend` | enum | Yes | | Catalog backend type (see below). No default - the field is required |
| `warehouse` | string | Yes | | Warehouse location (e.g., `s3://warehouse/`) |
| `properties` | map | No | `{}` | Additional catalog-specific properties |
| `cache` | object | No | | IO cache configuration (see [Cache Configuration](#cache-configuration)) |

### Catalog Backends

#### S3 Catalog (Default)

{{product_name}}'s own catalog. Catalog state is a `root.json` object in object storage, updated by compare-and-swap, so no external catalog service is required:

```yaml
catalog:
  backend: !s3
    warehouse: catalog
  warehouse: s3://warehouse/
  properties:
    bucket: warehouse
    region: us-east-1
    endpoint: http://rustfs:9000
```

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `warehouse` (inside `!s3`) | string | Yes | Object-storage key prefix holding the catalog state |
| `properties.bucket` | string | Yes | Bucket holding the catalog state |
| `properties.region` | string | Yes | Region for the catalog's S3 client |
| `properties.endpoint` | string | No | Custom endpoint for S3-compatible storage. Omit for real AWS S3 |

#### REST Catalog (Nessie)

```yaml
catalog:
  backend: !rest
    uri: http://nessie:19120/iceberg
  warehouse: s3://warehouse/
  properties:
    prefix: main
```

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `uri` | string | Yes | REST catalog endpoint URL (must start with `http://` or `https://`) |

#### AWS S3 Tables

```yaml
catalog:
  backend: !s3tables
    table_bucket_arn: arn:aws:s3tables:us-east-1:123456789012:bucket/my-tables
  warehouse: s3://warehouse/
```

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `table_bucket_arn` | string | Yes | S3 Tables bucket ARN (format: `arn:aws:s3tables:<region>:<account>:bucket/<name>`) |

#### AWS Glue

```yaml
catalog:
  backend: !glue
    catalog_id: "123456789012"
  warehouse: s3://warehouse/
```

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `catalog_id` | string | No | 12-digit AWS account ID. When omitted, the default account catalog is used |

#### In-Memory (Testing)

```yaml
catalog:
  backend: !memory
  warehouse: /tmp/icegate/warehouse
```

### Cache Configuration

The optional `cache` section enables a foyer hybrid cache (memory + disk) to reduce S3 round-trips for repeated reads. Recommended for production query services.

```yaml
catalog:
  backend: !s3
    warehouse: catalog
  warehouse: s3://warehouse/
  properties:
    bucket: warehouse
    region: us-east-1
    endpoint: http://rustfs:9000
  cache:
    memory_size_mb: 1024
    disk_dir: /tmp/icegate/cache
    disk_size_mb: 4096
    stat_ttl_secs: 300
    max_write_cache_size_mb: 128
    prefetch:
      max_prefetch_bytes: 1048576
```

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `memory_size_mb` | integer | Yes | | Memory cache capacity in MiB |
| `disk_dir` | string | Yes | | Directory for disk cache storage |
| `disk_size_mb` | integer | Yes | | Disk cache capacity in MiB |
| `stat_ttl_secs` | integer | No | | TTL in seconds for caching S3 HEAD responses |
| `max_write_cache_size_mb` | integer | No | | Max value size in MiB to cache on writes. Larger files bypass the cache |
| `prefetch.max_prefetch_bytes` | integer | No | | Max bytes to prefetch for Parquet column chunks |

## Storage Configuration

The `storage` section configures the object storage backend. Shared by all services.

### S3 / S3-Compatible (RustFS)

```yaml
storage:
  backend: !s3
    bucket: warehouse
    region: us-east-1
    endpoint: http://rustfs:9000
```

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `bucket` | string | Yes | | S3 bucket name |
| `region` | string | Yes | | AWS region |
| `endpoint` | string | No | | Custom endpoint URL for S3-compatible storage (RustFS, etc.) |

### Local Filesystem

```yaml
storage:
  backend: !filesystem
    root_path: /var/data/icegate
```

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `root_path` | string | Yes | Root directory for data storage |

### In-Memory (Testing)

```yaml
storage:
  backend: !memory
```

## Ingest Service Configuration

Full reference for the Ingest service (`ingest run -c ingest.yaml`).

### Complete Example

```yaml
catalog:
  backend: !s3
    warehouse: catalog
  warehouse: s3://warehouse/
  properties:
    bucket: warehouse
    region: us-east-1
    endpoint: http://rustfs:9000

storage:
  backend: !s3
    bucket: warehouse
    region: us-east-1
    endpoint: http://rustfs:9000

queue:
  common:
    base_path: s3://queue/
    channel_capacity: 1024
    max_row_group_size: 8192
  write:
    write_retries: 5
    compression: zstd
    records_per_flush_multiplier: 1
    max_bytes_per_flush: 67108864
    flush_interval_ms: 200

shift:
  read:
    max_record_batches_per_task: 1024
    max_input_bytes_per_task: 67108864
    plan_segment_read_parallelism: 8
    shift_segment_read_parallelism: 8
  write:
    row_group_size: 8192
    max_file_size_mb: 64
    table_cache_ttl_secs: 60
  jobsmanager:
    worker_count: 4
    poll_interval_ms: 1000
    iteration_interval_millisecs: 30000
    storage:
      endpoint: http://rustfs:9000
      bucket: jobs
      prefix: shifter
      region: us-east-1
      use_ssl: false
      job_state_codec: json
      request_timeout_secs: 5

otlp_http:
  enabled: true
  host: 0.0.0.0
  port: 4318

otlp_grpc:
  enabled: true
  host: 0.0.0.0
  port: 4317

metrics:
  enabled: true
  host: 0.0.0.0
  port: 9091
  path: /metrics

tracing:
  enabled: true
  service_name: icegate-ingest
  otlp_endpoint: http://jaeger:4317
  sample_ratio: 1.0
```

### OTLP Receivers

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `otlp_http.enabled` | bool | `true` | Enable OTLP HTTP receiver |
| `otlp_http.host` | string | `0.0.0.0` | Bind address |
| `otlp_http.port` | integer | `4318` | HTTP port (OTLP standard) |
| `otlp_grpc.enabled` | bool | `true` | Enable OTLP gRPC receiver |
| `otlp_grpc.host` | string | `0.0.0.0` | Bind address |
| `otlp_grpc.port` | integer | `4317` | gRPC port (OTLP standard) |

### Queue (WAL) Configuration

Controls how incoming data is written to the Write-Ahead Log.

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `queue.common.base_path` | string | | Base path for WAL segments (e.g., `s3://queue/`) |
| `queue.common.channel_capacity` | integer | `1024` | Bounded channel capacity for backpressure |
| `queue.common.max_row_group_size` | integer | `8192` | Max rows per Parquet row group |
| `queue.write.write_retries` | integer | `5` | Number of retry attempts for write operations |
| `queue.write.compression` | enum | `zstd` | Parquet compression: `none`, `snappy`, `gzip`, `lzo`, `brotli`, `lz4`, `zstd` |
| `queue.write.records_per_flush_multiplier` | integer | `1` | Row groups to accumulate before flush |
| `queue.write.max_bytes_per_flush` | integer | `67108864` | Max bytes (64 MiB) before flush |
| `queue.write.flush_interval_ms` | integer | `200` | Max time in ms before flush |
| `queue.read.metadata_entries_cache_capacity` | integer | `2048` | LRU cache size for Parquet metadata entries |

### Shift (WAL → Iceberg) Configuration

Controls how WAL data is compacted and written to Iceberg tables.

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `shift.read.max_record_batches_per_task` | integer | `1024` | Max row groups per shift task |
| `shift.read.max_input_bytes_per_task` | integer | `67108864` | Max input bytes (64 MiB) per shift task |
| `shift.read.plan_segment_read_parallelism` | integer | `8` | Parallel WAL segment reads during planning |
| `shift.read.shift_segment_read_parallelism` | integer | `8` | Parallel WAL segment reads during shift |
| `shift.write.row_group_size` | integer | `8192` | Rows per Iceberg Parquet row group |
| `shift.write.max_file_size_mb` | integer | `64` | Max Iceberg data file size in MiB |
| `shift.write.table_cache_ttl_secs` | integer | `60` | TTL for cached Iceberg table metadata |
| `shift.jobsmanager.worker_count` | integer | `CPUs/2` | Number of job manager workers |
| `shift.jobsmanager.poll_interval_ms` | integer | `1000` | Polling interval for workers |
| `shift.jobsmanager.iteration_interval_millisecs` | integer | `30000` | Interval between job iterations |

### Job Manager Storage

The job manager stores shift job state in a separate S3 bucket.

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `shift.jobsmanager.storage.endpoint` | string | | S3 endpoint URL |
| `shift.jobsmanager.storage.bucket` | string | | Bucket name for job state |
| `shift.jobsmanager.storage.prefix` | string | `shifter` | Object key prefix |
| `shift.jobsmanager.storage.region` | string | `us-east-1` | AWS region |
| `shift.jobsmanager.storage.use_ssl` | bool | `false` | Use HTTPS for the endpoint |
| `shift.jobsmanager.storage.job_state_codec` | enum | `json` | Serialization format: `json` or `cbor` |
| `shift.jobsmanager.storage.request_timeout_secs` | integer | `5` | S3 request timeout in seconds |
| `shift.jobsmanager.storage.access_key_id` | string | | S3 access key (falls back to `AWS_ACCESS_KEY_ID` env) |
| `shift.jobsmanager.storage.secret_access_key` | string | | S3 secret key (falls back to `AWS_SECRET_ACCESS_KEY` env) |

## Query Service Configuration

Full reference for the Query service (`query run -c query.yaml`).

### Complete Example

```yaml
catalog:
  backend: !s3
    warehouse: catalog
  warehouse: s3://warehouse/
  properties:
    bucket: warehouse
    region: us-east-1
    endpoint: http://rustfs:9000
  cache:
    memory_size_mb: 1024
    disk_dir: /tmp/icegate/cache
    disk_size_mb: 4096

storage:
  backend: !s3
    bucket: warehouse
    region: us-east-1
    endpoint: http://rustfs:9000

engine:
  batch_size: 8192
  target_partitions: 4
  catalog_name: iceberg
  refresh_interval_secs: 15
  max_age_secs: 30
  wal_query_enabled: false
  wal_metadata_size_hint: 65536

queue:
  common:
    base_path: s3://queue/

loki:
  enabled: true
  host: 0.0.0.0
  port: 3100

prometheus:
  enabled: true
  host: 0.0.0.0
  port: 9090

tempo:
  enabled: true
  host: 0.0.0.0
  port: 3200

metrics:
  enabled: true
  host: 0.0.0.0
  port: 9091
  path: /metrics

tracing:
  enabled: true
  service_name: icegate-query
  otlp_endpoint: http://jaeger:4317
  sample_ratio: 1.0
```

### Query Engine

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `engine.batch_size` | integer | `8192` | DataFusion batch size (rows processed at once) |
| `engine.target_partitions` | integer | `4` | Parallel execution partitions (set to CPU core count) |
| `engine.catalog_name` | string | `iceberg` | Catalog name in SQL (e.g., `SELECT * FROM iceberg.icegate.logs`) |
| `engine.refresh_interval_secs` | integer | `15` | Background catalog metadata refresh interval |
| `engine.max_age_secs` | integer | `30` | Max age before cached catalog is considered stale. Must be >= `refresh_interval_secs` |
| `engine.wal_query_enabled` | bool | `false` | Include WAL (hot) data in query results for real-time access |
| `engine.wal_metadata_size_hint` | integer | `65536` | Bytes to read from file tail in one request for WAL footer. Set to `null` for DataFusion default |

{% note info "Real-Time Queries with WAL" %}

When `engine.wal_query_enabled` is `true`, the query service reads both committed Iceberg data and uncommitted WAL segments. This allows querying data that is only seconds old, before it has been shifted to Iceberg tables.

**Note:** The `/labels`, `/label/{name}/values`, and `/series` metadata endpoints always read from Iceberg only, regardless of this setting.

{% endnote %}

### Query API Servers

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `loki.enabled` | bool | `true` | Enable Loki-compatible log query API |
| `loki.host` | string | `0.0.0.0` | Bind address |
| `loki.port` | integer | `3100` | Loki API port |
| `prometheus.enabled` | bool | `true` | Serve the Prometheus query API. Routes are registered, but every handler except `/-/ready` returns `501 Not Implemented` - PromQL is not implemented yet. This is not the metrics endpoint; that is the `metrics` block on port 9091 |
| `prometheus.host` | string | `0.0.0.0` | Bind address |
| `prometheus.port` | integer | `9090` | Prometheus API port |
| `tempo.enabled` | bool | `true` | Enable Tempo-compatible trace API |
| `tempo.host` | string | `0.0.0.0` | Bind address |
| `tempo.port` | integer | `3200` | Tempo API port |

## Maintain Service Configuration

The Maintain service only requires catalog and storage configuration:

```yaml
catalog:
  backend: !s3
    warehouse: catalog
  warehouse: s3://warehouse/
  properties:
    bucket: warehouse
    region: us-east-1
    endpoint: http://rustfs:9000

storage:
  backend: !s3
    bucket: warehouse
    region: us-east-1
    endpoint: http://rustfs:9000
```

### Maintain CLI

```bash
# Create all Iceberg tables (first-time setup)
maintain migrate create -c maintain.yaml

# Upgrade existing table schemas
maintain migrate upgrade -c maintain.yaml

# Dry-run (show what would be done)
maintain migrate create -c maintain.yaml --dry-run
maintain migrate upgrade -c maintain.yaml --dry-run
```

## Metrics Configuration

All services expose Prometheus metrics via a standalone HTTP server.

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `metrics.enabled` | bool | `false` | Enable Prometheus metrics endpoint |
| `metrics.host` | string | `127.0.0.1` | Bind address |
| `metrics.port` | integer | `9091` | Metrics server port |
| `metrics.path` | string | `/metrics` | URL path for metrics |

## Tracing Configuration

All services can export OpenTelemetry traces for self-observability.

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `tracing.enabled` | bool | `true` | Enable tracing |
| `tracing.service_name` | string | | Service name for traces |
| `tracing.otlp_endpoint` | string | | OTLP endpoint URL. Falls back to `OTEL_EXPORTER_OTLP_ENDPOINT` env |
| `tracing.sample_ratio` | float | `1.0` | Sampling ratio (0.0 to 1.0). Set lower in production |

Example with Jaeger:

```yaml
tracing:
  enabled: true
  service_name: icegate-ingest
  otlp_endpoint: http://jaeger:4317
  sample_ratio: 0.1  # Sample 10% of traces in production
```

## Development Environment

For local development, use the provided Docker Compose configuration:

```bash
# Start core services with hot-reload
make dev

# Start core services in release mode
make run-core-release

# Start with load generator
make run-load-release

# Start with monitoring (Jaeger, Prometheus, Grafana)
make run-analytics-release
```

Environment variables for local development:

```bash
export AWS_ACCESS_KEY_ID=rustfsadmin
export AWS_SECRET_ACCESS_KEY=rustfsadmin
export AWS_REGION=us-east-1
```

## Next Steps

- Learn about [Data Ingestion](../guides/ingestion.md)
- Explore [Querying](../guides/querying.md) capabilities
- Set up [Multi-Tenancy](../guides/multi-tenancy.md)

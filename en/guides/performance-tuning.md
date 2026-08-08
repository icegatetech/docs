---
title: Performance Tuning
description: Optimize {{product_name}} ingestion throughput, query performance, and compaction
---

# Performance Tuning

This guide covers tuning {{product_name}} for high-volume workloads across ingestion, compaction, and query paths.

## Architecture Overview

Data flows through three stages, each with independent tuning parameters:

1. **Ingest** — receives OTLP data, writes to WAL (Write-Ahead Log)
2. **Shift** — compacts WAL segments into optimized Iceberg Parquet files
3. **Query** — reads from Iceberg tables (and optionally WAL) via DataFusion

## Ingestion Tuning

### WAL Write Configuration

The WAL queue buffers incoming data before writing to object storage. Key parameters:

```yaml
queue:
  common:
    channel_capacity: 1024       # In-memory buffer size (records)
    max_row_group_size: 8192     # Rows per Parquet row group
  write:
    flush_interval_ms: 200       # Flush frequency (ms)
    max_bytes_per_flush: 67108864  # Max flush size (64 MiB)
    records_per_flush_multiplier: 1  # Multiplier for flush batch
    compression: zstd            # none|snappy|gzip|lzo|brotli|lz4|zstd
    write_retries: 5             # Retry count on write failure
```

#### High-Throughput Configuration

For high-volume ingestion (>10k events/sec per replica):

```yaml
queue:
  common:
    channel_capacity: 4096       # Larger buffer for burst absorption
    max_row_group_size: 16384    # Larger row groups for better compression
  write:
    flush_interval_ms: 500       # Less frequent flushes, larger batches
    max_bytes_per_flush: 134217728  # 128 MiB per flush
    records_per_flush_multiplier: 2
    compression: zstd
```

#### Low-Latency Configuration

For near-real-time data availability:

```yaml
queue:
  common:
    channel_capacity: 512
    max_row_group_size: 4096
  write:
    flush_interval_ms: 100       # Flush every 100ms
    max_bytes_per_flush: 33554432  # 32 MiB
    compression: lz4             # Faster compression
```

### Horizontal Scaling

The Ingest service is stateless — scale replicas to increase throughput:

```yaml
# Helm values.yaml
ingest:
  replicaCount: 3
  resources:
    requests:
      cpu: "2"
      memory: 4Gi
    limits:
      cpu: "4"
      memory: 8Gi
```

All replicas write to the same WAL location in object storage. No coordination is needed.

### OTLP Protocol Selection

| Protocol | Best For | Trade-off |
|----------|----------|-----------|
| gRPC (4317) | High throughput, SDK-native | Lower per-message overhead |
| HTTP Protobuf (4318) | Load balancer compatibility | Efficient encoding |
| HTTP JSON (4318) | Debugging, testing | 2-3x larger payloads |

Use protobuf encoding in production for best throughput:

```yaml
# OpenTelemetry Collector exporter config
exporters:
  otlp/icegate:
    endpoint: icegate-ingest:4317
    tls:
      insecure: true
    headers:
      X-Scope-OrgID: my-tenant
```

## Shift (Compaction) Tuning

The shift process converts WAL segments into optimized Iceberg Parquet files.

### Key Parameters

```yaml
shift:
  read:
    max_record_batches_per_task: 128    # Batches per shift task
    max_input_bytes_per_task: 67108864  # 64 MiB input limit per task
    plan_segment_read_parallelism: 8    # Parallel segment planning
    shift_segment_read_parallelism: 8   # Parallel segment reading
  write:
    row_group_size: 8192         # Rows per output row group
    max_file_size_mb: 64         # Max output Parquet file size
    table_cache_ttl_secs: 60     # Iceberg table metadata cache TTL
  jobsmanager:
    worker_count: 4              # Concurrent shift workers
    poll_interval_ms: 1000       # Job polling interval
    iteration_interval_millisecs: 30000  # Shift cycle interval (30s)
```

### High-Throughput Shift

When WAL segments accumulate faster than they can be shifted:

```yaml
shift:
  read:
    max_record_batches_per_task: 256
    max_input_bytes_per_task: 134217728  # 128 MiB
    plan_segment_read_parallelism: 16
    shift_segment_read_parallelism: 16
  write:
    row_group_size: 16384
    max_file_size_mb: 128
  jobsmanager:
    worker_count: 8              # More concurrent workers
    iteration_interval_millisecs: 10000  # Shift every 10s
```

### Monitoring Shift Health

Watch these metrics at `http://ingest:9091/metrics`:

| Metric | Healthy | Action If Unhealthy |
|--------|---------|---------------------|
| WAL file count | < 1000 | Increase `worker_count` |
| WAL total size | < 10 GB | Increase `iteration_interval_millisecs` frequency |
| Shift duration | < 300s | Reduce `max_input_bytes_per_task` |

## Query Tuning

### DataFusion Engine Configuration

```yaml
engine:
  batch_size: 8192               # Arrow batch size for query execution
  target_partitions: 4           # Parallel query partitions
  refresh_interval_secs: 15      # Catalog metadata refresh interval
  max_age_secs: 30               # Catalog cache staleness threshold
  wal_query_enabled: false       # Include WAL data in query results
  wal_metadata_size_hint: 65536  # WAL metadata buffer size (64 KB)
```

### High-Concurrency Configuration

For many concurrent queries:

```yaml
engine:
  batch_size: 4096               # Smaller batches = lower memory per query
  target_partitions: 8           # More parallelism per query
  refresh_interval_secs: 30      # Less frequent metadata refreshes

# Helm values.yaml
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

### Real-Time Query Configuration

To include WAL data in query results (data not yet shifted to Iceberg):

```yaml
engine:
  wal_query_enabled: true        # Enable WAL querying
  wal_metadata_size_hint: 131072 # 128 KB buffer for WAL metadata
  refresh_interval_secs: 5       # Frequent catalog refreshes
  max_age_secs: 10               # Short cache TTL
```

{% note info %}

Enabling WAL querying adds latency to queries because the engine must scan both Iceberg tables and WAL segments. Use only when near-real-time data access is required.

{% endnote %}

### Cache Configuration

Enable the IO cache for production query services to reduce object storage reads:

```yaml
catalog:
  cache:
    enabled: true
    memory_size_mb: 1024         # In-memory cache (1 GB)
    disk_dir: /tmp/icegate/cache
    disk_size_mb: 4096           # On-disk cache (4 GB)
    stat_ttl_secs: 300           # Cache stat/HEAD responses for 5 min
    max_write_cache_size_mb: 2   # Write buffer
    prefetch:
      enabled: true              # Prefetch metadata
```

### Query Optimization Tips

1. **Filter on partition keys first**: Always include `tenant_id` and `timestamp` range in queries. This enables Iceberg partition pruning.

   ```logql
   # Good: timestamp range is specified via API parameters
   {service_name="api"} |= "error"

   # The Loki API start/end parameters drive partition pruning
   curl -G http://localhost:3100/loki/api/v1/query_range \
     --data-urlencode 'query={service_name="api"}' \
     --data-urlencode 'start=1704067200' \
     --data-urlencode 'end=1704153600' \
     -H "X-Scope-OrgID: my-tenant"
   ```

2. **Use the explain endpoint**: Check query execution plans:

   ```bash
   curl -G http://localhost:3100/loki/api/v1/explain \
     --data-urlencode 'query={service_name="api"} |= "error"' \
     -H "X-Scope-OrgID: my-tenant"
   ```

3. **Limit result sets**: Use the `limit` parameter to cap results:

   ```bash
   curl -G http://localhost:3100/loki/api/v1/query_range \
     --data-urlencode 'query={service_name="api"}' \
     --data-urlencode 'limit=100' \
     -H "X-Scope-OrgID: my-tenant"
   ```

## Resource Sizing Guide

| Workload | Ingest CPU | Ingest RAM | Query CPU | Query RAM |
|----------|-----------|-----------|----------|----------|
| Small (<1k events/sec) | 1 core | 2 GB | 2 cores | 4 GB |
| Medium (1k-10k events/sec) | 2-4 cores | 4-8 GB | 4 cores | 8 GB |
| Large (10k-100k events/sec) | 4+ cores, 2+ replicas | 8 GB | 4-8 cores, 2+ replicas | 16-32 GB |

## Next Steps

- Configure [data retention](data-retention.md) for storage management
- Set up [deployment](../operations/deployment.md) for production
- Monitor health with [maintenance](../operations/maintenance.md) procedures

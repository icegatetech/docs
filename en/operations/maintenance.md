---
title: Maintenance
description: Maintain {{product_name}} for optimal performance
---

# Maintenance

This guide covers routine maintenance operations for IceGate.

## Schema Migration

### Initial Setup

Create all Iceberg tables for the first time:

```bash
maintain migrate create -c maintain.yaml
```

### Schema Upgrades

Upgrade existing table schemas when updating {{product_name}}:

```bash
maintain migrate upgrade -c maintain.yaml
```

### Dry Run

Preview what would be done without executing:

```bash
maintain migrate create -c maintain.yaml --dry-run
maintain migrate upgrade -c maintain.yaml --dry-run
```

### Migration Process

1. Connect to Iceberg catalog
2. Check existing table schemas
3. Create missing tables (or alter existing ones)
4. Report migration status

## Data Compaction (Shift)

The Ingest service automatically shifts WAL data into optimized Iceberg tables via the built-in shift process.

### How Shift Works

1. Job manager monitors WAL segments
2. Groups segments into shift tasks
3. Reads WAL Parquet files in parallel
4. Merges and re-partitions data
5. Writes optimized Iceberg data files
6. Commits a new snapshot to the catalog, recording the last committed WAL offset in the snapshot summary

Shift does not delete WAL segments. An object lifecycle rule on the queue bucket reclaims them, and the offset in the snapshot summary is what lets shift resume where it left off.

### Tuning Shift Performance

Key configuration parameters in the Ingest service config:

```yaml
shift:
  read:
    max_record_batches_per_task: 1024
    max_input_bytes_per_task: 67108864  # 64 MiB
    plan_segment_read_parallelism: 8
    shift_segment_read_parallelism: 8
  write:
    row_group_size: 8192
    max_file_size_mb: 64
    table_cache_ttl_secs: 60
  jobsmanager:
    worker_count: 4           # Half of available CPUs by default
    poll_interval_ms: 1000
    iteration_interval_millisecs: 30000
```

See [Configuration](../getting-started/configuration.md#shift-wal--iceberg-configuration) for full parameter reference.

## Table Optimization

### Optimize File Sizes

Rewrite small files into larger, optimized files:

```sql
ALTER TABLE icegate.logs EXECUTE optimize;
```

### Expire Snapshots

Remove old snapshots to reclaim storage:

```sql
ALTER TABLE icegate.logs
EXECUTE expire_snapshots(retention_threshold => '7d');
```

### Remove Orphan Files

Delete unreferenced data files:

```sql
ALTER TABLE icegate.logs
EXECUTE remove_orphan_files(retention_threshold => '1d');
```

## Data Retention

### Manual Deletion

Delete data older than a specific date:

```sql
DELETE FROM icegate.logs
WHERE timestamp < TIMESTAMP '2024-01-01 00:00:00 UTC';
```

## Monitoring

### Key Metrics

Monitor these metrics for maintenance health (available at `http://ingest:9091/metrics`):

| Metric | Description | Alert Threshold |
|--------|-------------|-----------------|
| WAL file count | Number of unprocessed WAL files | > 1000 |
| WAL total size | Total WAL size in bytes | > 10 GB |
| Shift duration | Time to complete a shift task | > 300s |
| Snapshot count | Active Iceberg snapshots | > 100 |

### Health Checks

```bash
# Check query service readiness
curl http://localhost:3100/ready

# Check ingest service health
curl http://localhost:4318/health
```

## Backup and Recovery

### Catalog Backup

Nessie stores catalog metadata. Back up the RocksDB data:

```bash
# Stop Nessie
docker stop nessie

# Backup data directory
tar -czf nessie-backup.tar.gz /data/nessie

# Restart Nessie
docker start nessie
```

### Data Recovery

Iceberg supports time-travel queries. To recover from accidental deletion:

```sql
-- List available snapshots
SELECT * FROM icegate.logs$snapshots;

-- Query data at specific snapshot
SELECT * FROM icegate.logs FOR VERSION AS OF 123456789;

-- Rollback to previous snapshot
CALL icegate.system.rollback_to_snapshot('logs', 123456789);
```

### Object Storage Backup

Enable versioning on your S3 bucket for point-in-time recovery:

```bash
aws s3api put-bucket-versioning \
  --bucket icegate-warehouse \
  --versioning-configuration Status=Enabled
```

## Performance Tuning

### Query Performance

- Ensure partitions are properly pruned (filter on `tenant_id`, `timestamp`)
- Monitor query plan with `/loki/api/v1/explain`
- Increase query service memory for complex aggregations
- Enable catalog cache for production query services

### Write Performance

- Scale Ingest service replicas for higher throughput
- Tune `queue.write.flush_interval_ms` and `queue.write.max_bytes_per_flush`
- Choose appropriate compression codec (ZSTD for best ratio, Snappy for speed)
- Monitor WAL write latency

### Compaction Performance

- Increase `shift.read.plan_segment_read_parallelism` for faster reads
- Increase `shift.jobsmanager.worker_count` for more concurrent tasks
- Adjust `shift.jobsmanager.iteration_interval_millisecs` for more frequent shifts

## Next Steps

- Set up [Troubleshooting](troubleshooting.md) procedures
- Review [Deployment](deployment.md) configuration
- Understand the [Data Model](../architecture/data-model.md)

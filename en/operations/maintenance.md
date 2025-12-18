---
title: Maintenance
description: Maintain IceGate for optimal performance
---

# Maintenance

This guide covers routine maintenance operations for IceGate.

## Data Compaction

The Maintain service automatically compacts WAL files into optimized Iceberg tables.

### Compaction Process

1. Monitor WAL file count and size
2. When threshold reached, read WAL files
3. Sort and merge data by partition keys
4. Write new Iceberg data files with optimal row group sizes
5. Commit new snapshot to catalog
6. Delete processed WAL files

### Compaction Configuration

```yaml
maintain:
  compaction:
    interval: 5m
    min_files: 10
    min_size_bytes: 104857600  # 100 MB
    target_file_size: 134217728  # 128 MB
```

### Manual Compaction

Trigger compaction via CLI:

```bash
icegate-maintain compact --table logs
```

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

## Schema Migration

### Running Migrations

Initialize or migrate table schemas:

```bash
icegate-maintain migrate --catalog-uri http://nessie:19120/api/v1
```

### Migration Process

1. Connect to Iceberg catalog
2. Check existing table schemas
3. Create missing tables
4. Alter existing tables for schema changes
5. Report migration status

## Data Retention

### TTL Configuration

Configure data retention per table:

```yaml
maintain:
  retention:
    logs:
      days: 30
    spans:
      days: 14
    metrics:
      days: 90
```

### Manual Deletion

Delete data older than a specific date:

```sql
DELETE FROM icegate.logs
WHERE timestamp < TIMESTAMP '2024-01-01 00:00:00 UTC';
```

## Monitoring

### Key Metrics

Monitor these metrics for maintenance health:

| Metric | Description | Alert Threshold |
|--------|-------------|-----------------|
| `wal_files_count` | Number of WAL files | > 1000 |
| `wal_size_bytes` | Total WAL size | > 10 GB |
| `compaction_duration_seconds` | Compaction time | > 300s |
| `snapshot_count` | Active snapshots | > 100 |

### Health Checks

```bash
# Check maintenance service health
curl http://maintain:8080/health

# Check compaction status
curl http://maintain:8080/status/compaction
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

- Ensure partitions are properly pruned (filter on tenant_id, timestamp)
- Monitor query plan with `/loki/api/v1/explain`
- Increase query service memory for complex aggregations

### Write Performance

- Scale Ingest service replicas for higher throughput
- Tune batch sizes and flush intervals
- Monitor WAL write latency

### Compaction Performance

- Adjust compaction thresholds based on workload
- Schedule heavy compaction during low-traffic periods
- Monitor compaction queue depth

## Next Steps

- Set up [Troubleshooting](troubleshooting.md) procedures
- Review [Deployment](deployment.md) configuration
- Understand the [Data Model](../architecture/data-model.md)

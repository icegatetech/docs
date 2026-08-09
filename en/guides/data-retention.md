---
title: Data Retention
description: Control how long data lives in {{product_name}} - WAL and Iceberg retention, snapshot management, retention strategies, backup, and storage cost optimization.
---

# Data Retention

This guide covers managing the data lifecycle in {{product_name}}, from WAL segments through Iceberg table maintenance.

## Data Lifecycle

Data in {{product_name}} moves through three stages:

1. **WAL (Write-Ahead Log)** - temporary Parquet files in object storage, written by Ingest
2. **Iceberg tables** - optimized, partitioned Parquet files managed by Apache Iceberg
3. **Snapshots** - Iceberg metadata tracking table versions over time

Each stage has independent retention controls.

## WAL Retention

Shift does not delete WAL segments after committing them to Iceberg - a lifecycle rule on the queue bucket is what reclaims them, so configure one:

{% note warning %}

Size the expiration from your worst-case unshifted-WAL window, not for convenience. A segment is only safe to expire once shift has committed it and recorded its offset in an Iceberg snapshot. If shift is stopped, backlogged, or recovering for longer than the expiration, the rule deletes segments whose offsets were never committed. The snapshot offset only tells shift where to resume - it cannot rebuild a deleted segment, so that is acknowledged data lost. One day suits the demo stack; choose yours from how long ingest can plausibly run without a successful shift commit, and alert on shift lag rather than relying on the rule to stay ahead of it.

{% endnote %}

The bucket in both commands below is the one from `queue.common.base_path` (`s3://queue/` by default). Substitute your own if you changed it - a rule applied to the wrong bucket leaves the real WAL bucket unmanaged.

### RustFS (and other S3-compatible stores)

RustFS speaks the S3 API, so the same `aws s3api` call the project's own bootstrap uses works against it:

```bash
# Set 1-day TTL on the queue bucket
aws --endpoint-url http://localhost:9000 s3api put-bucket-lifecycle-configuration \
  --bucket queue \
  --lifecycle-configuration '{"Rules":[{"ID":"expire-1d","Status":"Enabled","Filter":{"Prefix":""},"Expiration":{"Days":1}}]}'
```

### AWS S3 Lifecycle Rule

```bash
aws s3api put-bucket-lifecycle-configuration \
  --bucket queue \
  --lifecycle-configuration '{
    "Rules": [{
      "ID": "expire-wal-segments",
      "Status": "Enabled",
      "Filter": {},
      "Expiration": {
        "Days": 1
      }
    }]
  }'
```

### Shift Frequency

Control how often WAL data is compacted into Iceberg:

```yaml
shift:
  jobsmanager:
    iteration_interval_millisecs: 30000  # Shift cycle every 30s (default)
    worker_count: 4                      # Concurrent shift workers
```

Lower `iteration_interval_millisecs` reduces the time data spends in WAL.

## Iceberg Data Retention

### Delete by Time Range

Remove data older than a specific date using SQL:

```sql
-- Delete logs older than 30 days
DELETE FROM icegate.logs
WHERE timestamp < TIMESTAMP '2024-12-01 00:00:00 UTC';

-- Delete traces older than 7 days
DELETE FROM icegate.spans
WHERE start_timestamp < TIMESTAMP '2025-01-04 00:00:00 UTC';

-- Delete metrics older than 90 days
DELETE FROM icegate.metrics
WHERE timestamp < TIMESTAMP '2024-10-13 00:00:00 UTC';
```

### Delete by Tenant

Remove all data for a specific tenant:

```sql
DELETE FROM icegate.logs
WHERE tenant_id = 'old-tenant';
```

{% note info %}

Iceberg DELETE operations create new snapshots. The old data files are not physically removed until you expire snapshots and remove orphan files (see below).

{% endnote %}

## Snapshot Management

Iceberg maintains a history of table snapshots. Each write operation (shift, delete) creates a new snapshot.

### List Snapshots

```sql
SELECT * FROM icegate.logs$snapshots;
```

### Expire Old Snapshots

Remove snapshots older than a threshold to reclaim metadata storage:

```sql
-- Keep only snapshots from the last 7 days
ALTER TABLE icegate.logs
EXECUTE expire_snapshots(retention_threshold => '7d');

ALTER TABLE icegate.spans
EXECUTE expire_snapshots(retention_threshold => '7d');

ALTER TABLE icegate.metrics
EXECUTE expire_snapshots(retention_threshold => '7d');
```

### Remove Orphan Files

After expiring snapshots, delete unreferenced Parquet files:

```sql
ALTER TABLE icegate.logs
EXECUTE remove_orphan_files(retention_threshold => '1d');

ALTER TABLE icegate.spans
EXECUTE remove_orphan_files(retention_threshold => '1d');

ALTER TABLE icegate.metrics
EXECUTE remove_orphan_files(retention_threshold => '1d');
```

### Optimize File Sizes

Rewrite small files into larger, more efficient files:

```sql
ALTER TABLE icegate.logs EXECUTE optimize;
ALTER TABLE icegate.spans EXECUTE optimize;
ALTER TABLE icegate.metrics EXECUTE optimize;
```

## Retention Strategy Examples

### Short-Term Operational (7 Days)

For active debugging and incident response:

```sql
-- Run daily via cron or scheduled job
DELETE FROM icegate.logs WHERE timestamp < NOW() - INTERVAL '7' DAY;
DELETE FROM icegate.spans WHERE start_timestamp < NOW() - INTERVAL '7' DAY;

ALTER TABLE icegate.logs EXECUTE expire_snapshots(retention_threshold => '1d');
ALTER TABLE icegate.spans EXECUTE expire_snapshots(retention_threshold => '1d');

ALTER TABLE icegate.logs EXECUTE remove_orphan_files(retention_threshold => '1d');
ALTER TABLE icegate.spans EXECUTE remove_orphan_files(retention_threshold => '1d');
```

### Long-Term Forensic (90 Days)

For compliance and historical analysis:

```sql
-- Run weekly
DELETE FROM icegate.logs WHERE timestamp < NOW() - INTERVAL '90' DAY;
DELETE FROM icegate.spans WHERE start_timestamp < NOW() - INTERVAL '90' DAY;
DELETE FROM icegate.metrics WHERE timestamp < NOW() - INTERVAL '90' DAY;

ALTER TABLE icegate.logs EXECUTE expire_snapshots(retention_threshold => '7d');
ALTER TABLE icegate.logs EXECUTE remove_orphan_files(retention_threshold => '1d');
ALTER TABLE icegate.logs EXECUTE optimize;
```

### Tiered Retention

Different retention per data type:

| Data Type | Retention | Rationale |
|-----------|-----------|-----------|
| Logs | 30 days | High volume, operational use |
| Traces | 14 days | Debugging, usually short-lived |
| Metrics | 90 days | Trend analysis, capacity planning |

## Backup and Recovery

### Time-Travel Queries

Iceberg supports querying historical data by snapshot:

```sql
-- Query data as it existed at a specific snapshot
SELECT * FROM iceberg.logs FOR VERSION AS OF 123456789;
```

### Rollback to Previous State

Restore a table to a previous snapshot:

```sql
CALL icegate.system.rollback_to_snapshot('logs', 123456789);
```

### Object Storage Versioning

Enable S3 versioning for point-in-time recovery of the warehouse bucket:

```bash
aws s3api put-bucket-versioning \
  --bucket warehouse \
  --versioning-configuration Status=Enabled
```

### Catalog Backup

On the default S3 catalog there is no service to stop and no database to dump - the catalog is `root.json` plus the table metadata files, in the warehouse bucket. Enabling versioning on that bucket (above) already gives point-in-time recovery. For an off-site copy, sync the catalog prefix:

```bash
aws s3 sync s3://warehouse/catalog/ ./catalog-backup-$(date +%Y%m%d)/
```

Each object is replaced atomically - `root.json` by compare-and-swap, metadata files never in place - so no single object is ever copied half-written. The *set* is a different matter: `sync` lists and then copies, so commits landing during the run can leave the copy mixing catalog generations. For a point-in-time copy, read a single version from the versioned bucket, or take the copy while writes are quiesced, and verify it by restoring to a scratch prefix before relying on it.

If you run the REST catalog backend instead, back up Nessie's RocksDB storage:

```bash
# Stop Nessie
docker stop nessie

# Backup data directory
tar -czf nessie-backup-$(date +%Y%m%d).tar.gz /data/nessie

# Restart Nessie
docker start nessie
```

## Storage Cost Optimization

1. **Use ZSTD compression** (default) - best compression ratio for observability data
2. **Partition pruning** - queries skip irrelevant partitions when filtering by `tenant_id` and `timestamp`
3. **Regular compaction** - run `optimize` to merge small files and improve read performance
4. **Aggressive snapshot expiry** - old snapshots reference data files that cannot be cleaned up
5. **Object storage lifecycle rules** - set expiration policies on the queue bucket

## Next Steps

- Set up [performance tuning](performance-tuning.md) for high-throughput workloads
- Review [maintenance](../operations/maintenance.md) procedures
- Understand the [data model](../architecture/data-model.md) and partitioning strategy

---
title: Troubleshooting
description: Diagnose and resolve common IceGate issues
---

# Troubleshooting

This guide helps diagnose and resolve common issues with IceGate.

## Service Health

### Check Service Status

```bash
# Query service
curl http://localhost:3100/ready

# Ingest service
curl http://localhost:4318/health

# Maintain service
curl http://localhost:8080/health
```

### View Service Logs

```bash
# Docker Compose
docker compose logs -f query
docker compose logs -f ingest
docker compose logs -f maintain
```

## Connection Issues

### Cannot Connect to Query Service

**Symptoms:**

- Connection refused on port 3100
- Timeout errors

**Solutions:**

1. Verify service is running:

   ```bash
   docker ps | grep query
   ```

2. Check port binding:

   ```bash
   netstat -tlnp | grep 3100
   ```

3. Check service logs for errors:

   ```bash
   docker compose logs query | tail -100
   ```

### Cannot Connect to Object Storage

**Symptoms:**

- "Connection refused" to MinIO
- S3 authentication errors

**Solutions:**

1. Verify MinIO is running:

   ```bash
   curl http://localhost:9000/minio/health/ready
   ```

2. Check credentials:

   ```bash
   echo $AWS_ACCESS_KEY_ID
   echo $AWS_SECRET_ACCESS_KEY
   ```

3. Test S3 connection:

   ```bash
   aws s3 ls --endpoint-url http://localhost:9000
   ```

### Cannot Connect to Catalog

**Symptoms:**

- "Catalog unavailable" errors
- Table creation failures

**Solutions:**

1. Verify Nessie is running:

   ```bash
   curl http://localhost:19120/api/v1/trees
   ```

2. Check catalog configuration:

   ```yaml
   catalog:
     type: rest
     uri: http://nessie:19120/api/v1
   ```

## Query Issues

### Query Returns Empty Results

**Possible Causes:**

- Wrong tenant ID
- Time range outside data window
- Data not yet compacted

**Solutions:**

1. Verify tenant header:

   ```bash
   curl -H "X-Scope-OrgID: correct-tenant" ...
   ```

2. Check time range:

   ```bash
   # List available time range
   curl http://localhost:3100/loki/api/v1/labels \
     -H "X-Scope-OrgID: my-tenant"
   ```

3. Check WAL for recent data:

   ```bash
   aws s3 ls s3://warehouse/wal/ --recursive
   ```

### Query Timeout

**Symptoms:**

- Queries take too long
- 504 Gateway Timeout

**Solutions:**

1. Add time range filter:

   ```logql
   {service_name="api"} | timestamp > 1h ago
   ```

2. Reduce result limit:

   ```bash
   curl ... --data-urlencode 'limit=100'
   ```

3. Check query plan:

   ```bash
   curl http://localhost:3100/loki/api/v1/explain \
     --data-urlencode 'query={service_name="api"}' \
     -H "X-Scope-OrgID: my-tenant"
   ```

### Invalid Query Syntax

**Symptoms:**

- "parse error" responses
- 400 Bad Request

**Solutions:**

1. Validate LogQL syntax:
   - Labels must be in braces: `{service_name="api"}`
   - String values in quotes: `"value"`
   - Duration format: `[5m]`, `[1h]`

2. Check for unsupported features:
   - Pipeline parsers (json, logfmt) not yet supported
   - Some aggregations not implemented

## Ingestion Issues

### Data Not Appearing

**Symptoms:**

- Sent data but query returns empty
- No errors from ingest

**Solutions:**

1. Verify data was accepted:

   ```bash
   curl -v -X POST http://localhost:4318/v1/logs \
     -H "X-Scope-OrgID: my-tenant" \
     -H "Content-Type: application/json" \
     -d '...'
   ```

2. Check WAL files:

   ```bash
   aws s3 ls s3://warehouse/wal/logs/ --recursive
   ```

3. Wait for compaction (or query WAL directly)

### Ingestion Errors

**Common Errors:**

- `400 Bad Request`: Invalid OTLP format
- `503 Service Unavailable`: Storage unavailable
- `429 Too Many Requests`: Rate limited

**Solutions:**

1. Validate OTLP payload format
2. Check storage connectivity
3. Reduce ingestion rate or scale ingest replicas

## Performance Issues

### Slow Queries

1. **Add partition filters:**

   ```logql
   {tenant_id="my-tenant", service_name="api"}
   ```

2. **Limit time range:**

   ```bash
   --data-urlencode 'start=1704067200'
   --data-urlencode 'end=1704153600'
   ```

3. **Check table statistics:**

   ```sql
   SHOW STATS FOR icegate.logs;
   ```

### High Memory Usage

1. Reduce concurrent queries
2. Add query limits
3. Increase service memory allocation

## Getting Help

If issues persist:

1. Collect diagnostic information:

   ```bash
   # Service logs
   docker compose logs > logs.txt

   # System info
   docker stats > stats.txt
   ```

2. Check [GitHub Issues](https://github.com/icegatetech/icegate/issues)

3. Include:
   - IceGate version
   - Configuration (sanitized)
   - Error messages
   - Steps to reproduce

## Next Steps

- Review [Maintenance](maintenance.md) procedures
- Check [Deployment](deployment.md) configuration
- Understand the [Architecture](../architecture/overview.md)

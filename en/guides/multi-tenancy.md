---
title: Multi-Tenancy
description: Isolate tenants in {{product_name}} - tenant identification, data isolation guarantees, Grafana configuration, a worked three-tenant example, and best practices.
---

# Multi-Tenancy

{{product_name}} is designed as a multi-tenant system, providing data isolation between different organizations or teams.

## Tenant Identification

Tenants are identified by the `X-Scope-OrgID` header in all API requests.

### Ingestion

```bash
curl -X POST http://localhost:4318/v1/logs \
  -H "X-Scope-OrgID: tenant-123" \
  -H "Content-Type: application/json" \
  -d '...'
```

### Querying

```bash
curl -G http://localhost:3100/loki/api/v1/query_range \
  -H "X-Scope-OrgID: tenant-123" \
  --data-urlencode 'query={service_name="api-service"}'
```

## Data Isolation

### Storage Partitioning

All data tables are partitioned by `tenant_id`:

```sql
partitioning = ARRAY['tenant_id', 'account_id', 'day(timestamp)']
```

This ensures:

- **Query isolation**: Queries only access data for the specified tenant
- **Performance**: Partition pruning skips irrelevant tenant data
- **Security**: No cross-tenant data leakage

### Account-Level Partitioning

Within a tenant, data can be further partitioned by `account_id`:

```bash
curl -X POST http://localhost:4318/v1/logs \
  -H "X-Scope-OrgID: tenant-123" \
  -H "X-Account-ID: account-456" \
  -H "Content-Type: application/json" \
  -d '...'
```

## Grafana Configuration

Configure Grafana to send tenant headers:

### Data Source Configuration

```yaml
# grafana/provisioning/datasources/loki.yaml
apiVersion: 1
datasources:
  - name: Loki
    type: loki
    url: http://query:3100
    jsonData:
      httpHeaderName1: X-Scope-OrgID
    secureJsonData:
      httpHeaderValue1: ${TENANT_ID}
```

### Per-User Tenancy

For multi-user Grafana deployments, configure tenant mapping:

```yaml
datasources:
  - name: Loki
    type: loki
    url: http://query:3100
    jsonData:
      httpHeaderName1: X-Scope-OrgID
      httpHeaderValue1: $__user.orgId
```

## Architecture: Multi-Tenant Deployment

A multi-tenant {{product_name}} deployment uses a single cluster shared by all tenants. Data isolation is enforced at the storage layer:

```
Tenant A ──┐                          ┌── Iceberg partition: tenant_id="tenant-a"
Tenant B ──┤── Ingest (shared) ──WAL──┤── Iceberg partition: tenant_id="tenant-b"
Tenant C ──┘                          └── Iceberg partition: tenant_id="tenant-c"
                                            │
                                      Query (shared) ── partition pruning by tenant_id
```

Key design properties:

- **Shared compute**: All tenants share the same Ingest and Query services
- **Isolated storage**: Data is physically partitioned by `tenant_id` in Iceberg tables
- **Query isolation**: Partition pruning ensures queries only scan data for the requesting tenant
- **No cross-tenant leakage**: The `X-Scope-OrgID` header is required and validated on every request

### Storage Cost Optimization

Sharing Iceberg tables across tenants reduces storage overhead:

- **Single table schema** for all tenants (no per-tenant table management)
- **Partition pruning** skips data files not matching the tenant filter
- **Shared compaction**: The shift process optimizes files across all tenants
- **ZSTD compression** applied uniformly for best compression ratio

Compare to dedicated-table approaches:

| Approach | Storage Overhead | Operational Complexity | Isolation |
|----------|-----------------|----------------------|-----------|
| Shared tables + partition | Low | Low (single cluster) | Logical (partition pruning) |
| Separate tables per tenant | Medium | High (schema management per tenant) | Physical |
| Separate clusters per tenant | High | Very high | Full |

{{product_name}} uses the shared tables approach, which is optimal for SaaS and platform use cases where many tenants share similar data shapes.

## Concrete Example: Three Tenants

### Ingest from Three Teams

```bash
# Platform team
curl -X POST http://localhost:4318/v1/logs \
  -H "X-Scope-OrgID: team-platform" \
  -H "Content-Type: application/json" \
  -d '{
    "resourceLogs": [{
      "resource": {"attributes": [{"key": "service.name", "value": {"stringValue": "gateway"}}]},
      "scopeLogs": [{"logRecords": [{"timeUnixNano": "1704067200000000000", "body": {"stringValue": "Request received"}, "severityText": "INFO", "severityNumber": 9}]}]
    }]
  }'

# Backend team
curl -X POST http://localhost:4318/v1/logs \
  -H "X-Scope-OrgID: team-backend" \
  -H "Content-Type: application/json" \
  -d '{
    "resourceLogs": [{
      "resource": {"attributes": [{"key": "service.name", "value": {"stringValue": "order-service"}}]},
      "scopeLogs": [{"logRecords": [{"timeUnixNano": "1704067200000000000", "body": {"stringValue": "Order created"}, "severityText": "INFO", "severityNumber": 9}]}]
    }]
  }'

# Data team
curl -X POST http://localhost:4318/v1/logs \
  -H "X-Scope-OrgID: team-data" \
  -H "Content-Type: application/json" \
  -d '{
    "resourceLogs": [{
      "resource": {"attributes": [{"key": "service.name", "value": {"stringValue": "pipeline"}}]},
      "scopeLogs": [{"logRecords": [{"timeUnixNano": "1704067200000000000", "body": {"stringValue": "ETL batch complete"}, "severityText": "INFO", "severityNumber": 9}]}]
    }]
  }'
```

### Query Per Team

Each team only sees their own data:

```bash
# Platform team queries - sees only gateway logs
curl -G http://localhost:3100/loki/api/v1/query_range \
  --data-urlencode 'query={service_name=~".+"}' \
  --data-urlencode 'start=1704067200' \
  --data-urlencode 'end=1704153600' \
  -H "X-Scope-OrgID: team-platform"

# Backend team queries - sees only order-service logs
curl -G http://localhost:3100/loki/api/v1/query_range \
  --data-urlencode 'query={service_name=~".+"}' \
  --data-urlencode 'start=1704067200' \
  --data-urlencode 'end=1704153600' \
  -H "X-Scope-OrgID: team-backend"
```

## Best Practices

### Tenant Naming

- Use consistent, predictable tenant IDs (e.g., `team-platform`, `org-acme`)
- Allowed characters: ASCII alphanumeric, hyphens (`-`), underscores (`_`)
- Default tenant ID is `default` when no header is provided
- Consider using UUIDs for programmatic access

### Monitoring Per-Tenant Usage

Track log volume by tenant:

```logql
sum by (tenant_id) (
  count_over_time({job="app"}[1h])
)
```

Monitor per-tenant error rates:

```logql
sum by (tenant_id) (
  rate({severity_text="ERROR"}[5m])
)
```

Set up per-tenant Grafana dashboards using separate data sources (see [Grafana Integration](grafana-integration.md#multi-tenant-configuration)).

### Resource Limits

Consider implementing per-tenant limits:

- Query rate limiting (via reverse proxy)
- Storage quotas (monitor with per-tenant log volume metrics)
- Retention policies (see [Data Retention](data-retention.md))

## Next Steps

- Configure [Grafana](grafana-integration.md) with per-tenant data sources
- Set up [data retention](data-retention.md) policies per tenant
- Learn about [Deployment](../operations/deployment.md) options
- Explore the [Data Model](../architecture/data-model.md)

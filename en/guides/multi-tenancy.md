---
title: Multi-Tenancy
description: Configure and use multi-tenant isolation in IceGate
---

# Multi-Tenancy

IceGate is designed as a multi-tenant system, providing data isolation between different organizations or teams.

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

## Best Practices

### Tenant Naming

- Use consistent, predictable tenant IDs
- Avoid special characters
- Consider using UUIDs for programmatic access

### Monitoring

Monitor per-tenant usage:

```logql
sum by (tenant_id) (
  count_over_time({job="app"}[1h])
)
```

### Resource Limits

Consider implementing per-tenant limits:

- Query rate limiting
- Storage quotas
- Retention policies

## Next Steps

- Learn about [Deployment](../operations/deployment.md) options
- Explore the [Data Model](../architecture/data-model.md)
- See [Troubleshooting](../operations/troubleshooting.md) for common issues

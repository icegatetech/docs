---
title: Querying Data
description: Query {{product_name}} with LogQL - real-time queries against the WAL, implementation status, worked query examples, and how to call the HTTP API directly.
---

# Querying Data

{{product_name}} provides Loki- and Tempo-compatible APIs for querying observability data, plus Arrow Flight
SQL for general-purpose SQL. The
[Prometheus-compatible API](../api-reference/prometheus.md) is planned and not implemented yet -
query metrics through Flight SQL in the meantime. The API reference pages are authoritative on
which endpoints are served today.

## LogQL for Logs

LogQL is the query language for logs, compatible with Grafana Loki.

### Log Stream Selector

Select logs by labels:

```logql
# Select by service name
{service_name="api-service"}

# Multiple labels
{service_name="api-service", severity_text="ERROR"}

# Label regex matching
{service_name=~"api-.*"}

# Negative matching
{service_name!="internal-service"}
```

### Line Filters

Filter log lines by content:

```logql
# Contains
{service_name="api-service"} |= "error"

# Does not contain
{service_name="api-service"} != "debug"

# Regex match
{service_name="api-service"} |~ "status=[45][0-9][0-9]"

# Regex not match
{service_name="api-service"} !~ "health"
```

### Label Filters

Filter by label values:

```logql
# Numeric comparison
{service_name="api-service"} | severity_number > 8

# Duration comparison
{service_name="api-service"} | duration > 1s

# Bytes comparison
{service_name="api-service"} | bytes > 1KB
```

### Metric Queries

Aggregate logs into metrics:

```logql
# Count logs over time
count_over_time({service_name="api-service"}[5m])

# Rate of logs per second
rate({service_name="api-service"}[1m])

# Bytes throughput
bytes_rate({service_name="api-service"}[5m])

# Check for missing logs
absent_over_time({service_name="api-service"}[1h])
```

### Vector Aggregations

Aggregate across label dimensions:

```logql
# Sum by service
sum by (service_name) (count_over_time({job="app"}[5m]))

# Average rate
avg(rate({service_name=~".*"}[1m]))

# Top services by log volume
sum by (service_name) (bytes_rate({job="app"}[5m]))
```

## Real-Time Queries (WAL)

By default, the query service reads only committed Iceberg data. To also query data that has not yet been shifted to Iceberg (seconds-old WAL data), enable WAL queries in the query service configuration:

```yaml
engine:
  wal_query_enabled: true
  wal_metadata_size_hint: 65536  # Bytes for WAL footer reads
```

When enabled, queries read from both:

- **Iceberg tables** - Historical, compacted data
- **WAL segments** - Real-time data not yet shifted

**Note:** The `/labels`, `/label/{name}/values`, and `/series` metadata endpoints always read from Iceberg only, regardless of this setting.

## Implementation Status

| Feature | Status |
|---------|--------|
| Log Selection | ✅ Implemented |
| Label Matchers (`=`, `!=`, `=~`, `!~`) | ✅ Implemented |
| Line Filters (`\|=`, `!=`, `\|~`, `!~`) | ✅ Implemented |
| count_over_time | ✅ Implemented |
| rate | ✅ Implemented |
| bytes_over_time | ✅ Implemented |
| bytes_rate | ✅ Implemented |
| absent_over_time | ✅ Implemented |
| Vector aggregations (sum, avg, min, max, count) | ✅ Implemented |
| Pipeline parsers (json, logfmt) | ❌ Not yet |
| Unwrap aggregations | ❌ Not yet |

## Query Examples

### Recent Errors

```logql
{service_name="api-service", severity_text="ERROR"}
```

### Error Rate by Service

```logql
sum by (service_name) (
  rate({severity_text="ERROR"}[5m])
)
```

### Log Volume Trends

```logql
sum(count_over_time({job="app"}[1h]))
```

## Using the API

### Query Range

```bash
curl -G http://localhost:3100/loki/api/v1/query_range \
  --data-urlencode 'query={service_name="api-service"}' \
  --data-urlencode 'start=1704067200' \
  --data-urlencode 'end=1704153600' \
  --data-urlencode 'limit=1000' \
  -H "X-Scope-OrgID: my-tenant"
```

### Available Labels

```bash
curl http://localhost:3100/loki/api/v1/labels \
  -H "X-Scope-OrgID: my-tenant"
```

### Label Values

```bash
curl http://localhost:3100/loki/api/v1/label/service_name/values \
  -H "X-Scope-OrgID: my-tenant"
```

## Next Steps

- Explore the [Loki API](../api-reference/loki.md) reference
- Set up [Multi-Tenancy](multi-tenancy.md)
- Learn about the [Data Model](../architecture/data-model.md)

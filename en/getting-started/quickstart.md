---
title: Quick Start
description: Get started with IceGate in 5 minutes
---

# Quick Start

This guide walks you through ingesting your first logs and querying them with IceGate.

## Start the Development Environment

Start the full IceGate stack using Docker Compose:

```bash
make dev
```

This starts the following services:

| Service | Port | Description |
|---------|------|-------------|
| MinIO (S3) | 9000, 9001 | Object storage backend |
| Nessie | 19120 | Iceberg catalog |
| Query Service | 3100 | Loki-compatible API |
| Grafana | 3000 | Observability dashboard |
| Trino | 8080 | SQL query engine |

## Verify Services Are Running

Check that all services are healthy:

```bash
# Check Loki API
curl http://localhost:3100/ready

# Check Grafana
curl http://localhost:3000/api/health
```

## Send Test Logs

IceGate accepts logs via the OpenTelemetry Protocol (OTLP). You can use any OTLP-compatible collector or SDK.

### Using curl (OTLP HTTP)

```bash
curl -X POST http://localhost:4318/v1/logs \
  -H "Content-Type: application/json" \
  -H "X-Scope-OrgID: demo" \
  -d '{
    "resourceLogs": [{
      "resource": {
        "attributes": [
          {"key": "service.name", "value": {"stringValue": "my-service"}}
        ]
      },
      "scopeLogs": [{
        "logRecords": [{
          "timeUnixNano": "'$(date +%s)000000000'",
          "body": {"stringValue": "Hello from IceGate!"},
          "severityText": "INFO"
        }]
      }]
    }]
  }'
```

## Query Logs

### Using Loki API

Query logs using the Loki-compatible API:

```bash
# Query all logs from a service
curl -G http://localhost:3100/loki/api/v1/query_range \
  --data-urlencode 'query={service_name="my-service"}' \
  --data-urlencode 'start='$(date -v-1H +%s) \
  --data-urlencode 'end='$(date +%s) \
  -H "X-Scope-OrgID: demo"
```

### Using Grafana

1. Open Grafana at [http://localhost:3000](http://localhost:3000)
2. Navigate to Explore
3. Select the Loki data source
4. Enter a LogQL query: `{service_name="my-service"}`
5. Click "Run query"

## Query with LogQL

IceGate supports LogQL for querying logs:

```logql
# Filter by service
{service_name="my-service"}

# Filter with line contains
{service_name="my-service"} |= "error"

# Count logs over time
count_over_time({service_name="my-service"}[5m])

# Rate of logs
rate({service_name="my-service"}[1m])
```

## Next Steps

- Learn about [Configuration](configuration.md) options
- Explore [Data Ingestion](../guides/ingestion.md) in detail
- Understand [Querying](../guides/querying.md) capabilities

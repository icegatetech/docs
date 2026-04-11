---
title: Quick Start
description: Ingest and query your first observability data with IceGate
---

# Quick Start

This guide walks you through ingesting logs, traces, and metrics into IceGate and querying them via the API and Grafana.

{% note info %}

This guide assumes IceGate is already running. See [Installation](installation.md) for Helm deployment or [Development Setup](../development/setup.md) for a local environment.

{% endnote %}

## Ingest Logs

IceGate accepts data via the OpenTelemetry Protocol (OTLP) on the Ingest service.

### Send Logs via OTLP HTTP

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
          "body": {"stringValue": "User login successful"},
          "severityText": "INFO",
          "severityNumber": 9,
          "attributes": [
            {"key": "user.id", "value": {"stringValue": "user-42"}},
            {"key": "http.method", "value": {"stringValue": "POST"}}
          ]
        }]
      }]
    }]
  }'
```

### Send Logs via OTLP gRPC

Use any OpenTelemetry SDK. Example with Python:

```python
from opentelemetry.sdk._logs import LoggerProvider
from opentelemetry.sdk._logs.export import BatchLogRecordProcessor
from opentelemetry.exporter.otlp.proto.grpc._log_exporter import OTLPLogExporter

provider = LoggerProvider()
provider.add_log_record_processor(
    BatchLogRecordProcessor(
        OTLPLogExporter(
            endpoint="localhost:4317",
            headers={"X-Scope-OrgID": "demo"},
            insecure=True,
        )
    )
)
```

## Ingest Traces

Send distributed trace spans:

```bash
curl -X POST http://localhost:4318/v1/traces \
  -H "Content-Type: application/json" \
  -H "X-Scope-OrgID: demo" \
  -d '{
    "resourceSpans": [{
      "resource": {
        "attributes": [
          {"key": "service.name", "value": {"stringValue": "my-service"}}
        ]
      },
      "scopeSpans": [{
        "spans": [{
          "traceId": "5B8EFFF798038103D269B633813FC60C",
          "spanId": "EEE19B7EC3C1B174",
          "name": "GET /api/users",
          "kind": 2,
          "startTimeUnixNano": "'$(date +%s)000000000'",
          "endTimeUnixNano": "'$(date +%s)100000000'",
          "status": {"code": 1},
          "attributes": [
            {"key": "http.method", "value": {"stringValue": "GET"}},
            {"key": "http.status_code", "value": {"intValue": "200"}}
          ]
        }]
      }]
    }]
  }'
```

## Ingest Metrics

Send metrics data:

```bash
curl -X POST http://localhost:4318/v1/metrics \
  -H "Content-Type: application/json" \
  -H "X-Scope-OrgID: demo" \
  -d '{
    "resourceMetrics": [{
      "resource": {
        "attributes": [
          {"key": "service.name", "value": {"stringValue": "my-service"}}
        ]
      },
      "scopeMetrics": [{
        "metrics": [{
          "name": "http_requests_total",
          "sum": {
            "dataPoints": [{
              "startTimeUnixNano": "'$(date +%s)000000000'",
              "timeUnixNano": "'$(date +%s)000000000'",
              "asInt": "42",
              "attributes": [
                {"key": "method", "value": {"stringValue": "GET"}},
                {"key": "status", "value": {"stringValue": "200"}}
              ]
            }],
            "aggregationTemporality": 2,
            "isMonotonic": true
          }
        }]
      }]
    }]
  }'
```

## Query Logs with LogQL

IceGate provides a Loki-compatible API on the Query service (port 3100).

### Basic Log Query

```bash
curl -G http://localhost:3100/loki/api/v1/query_range \
  --data-urlencode 'query={service_name="my-service"}' \
  --data-urlencode 'start='$(date -d '1 hour ago' +%s 2>/dev/null || date -v-1H +%s) \
  --data-urlencode 'end='$(date +%s) \
  --data-urlencode 'limit=100' \
  -H "X-Scope-OrgID: demo"
```

### Filter by Severity

```bash
curl -G http://localhost:3100/loki/api/v1/query_range \
  --data-urlencode 'query={service_name="my-service", severity_text="ERROR"}' \
  --data-urlencode 'start='$(date -d '1 hour ago' +%s 2>/dev/null || date -v-1H +%s) \
  --data-urlencode 'end='$(date +%s) \
  -H "X-Scope-OrgID: demo"
```

### Search Log Content

```bash
curl -G http://localhost:3100/loki/api/v1/query_range \
  --data-urlencode 'query={service_name="my-service"} |= "login"' \
  --data-urlencode 'start='$(date -d '1 hour ago' +%s 2>/dev/null || date -v-1H +%s) \
  --data-urlencode 'end='$(date +%s) \
  -H "X-Scope-OrgID: demo"
```

### Aggregate Logs into Metrics

```bash
# Count logs per 5-minute window
curl -G http://localhost:3100/loki/api/v1/query_range \
  --data-urlencode 'query=count_over_time({service_name="my-service"}[5m])' \
  --data-urlencode 'start='$(date -d '1 hour ago' +%s 2>/dev/null || date -v-1H +%s) \
  --data-urlencode 'end='$(date +%s) \
  --data-urlencode 'step=300' \
  -H "X-Scope-OrgID: demo"

# Error rate per second
curl -G http://localhost:3100/loki/api/v1/query_range \
  --data-urlencode 'query=rate({severity_text="ERROR"}[1m])' \
  --data-urlencode 'start='$(date -d '1 hour ago' +%s 2>/dev/null || date -v-1H +%s) \
  --data-urlencode 'end='$(date +%s) \
  --data-urlencode 'step=60' \
  -H "X-Scope-OrgID: demo"
```

## Explore Labels and Series

### List All Labels

```bash
curl http://localhost:3100/loki/api/v1/labels \
  -H "X-Scope-OrgID: demo"
```

### Get Values for a Label

```bash
curl http://localhost:3100/loki/api/v1/label/service_name/values \
  -H "X-Scope-OrgID: demo"
```

### Find Matching Series

```bash
curl -G http://localhost:3100/loki/api/v1/series \
  --data-urlencode 'match[]={service_name=~"my-.*"}' \
  -H "X-Scope-OrgID: demo"
```

## Using Grafana

IceGate is compatible with Grafana's Loki data source for log visualization and dashboarding.

### Add IceGate as a Data Source

1. Open Grafana (default: [http://localhost:3000](http://localhost:3000))
2. Go to **Connections** > **Data sources** > **Add data source**
3. Select **Loki**
4. Set the URL to `http://icegate-query:3100` (or `http://localhost:3100` for local access)
5. Under **HTTP Headers**, add:
   - Header: `X-Scope-OrgID`
   - Value: `demo`
6. Click **Save & Test**

### Explore Logs

1. Go to **Explore**
1. Select the **Loki** data source
1. Enter a LogQL query: `{service_name="my-service"}`
1. Click **Run query**
1. Switch between **Logs** and **Graph** views

### Build a Dashboard

1. Go to **Dashboards** > **New** > **New Dashboard**
2. Add a **Logs panel**:
   - Query: `{service_name="my-service"}`
   - Visualization: Logs
3. Add a **Time series panel** for error rate:
   - Query: `sum by (service_name) (rate({severity_text="ERROR"}[5m]))`
   - Visualization: Time series
4. Add a **Stat panel** for log volume:
   - Query: `sum(count_over_time({service_name="my-service"}[1h]))`
   - Visualization: Stat

### Pre-Built Dashboards

If deployed with the Kustomize overlays or Docker Compose, Grafana comes pre-configured with IceGate dashboards for Ingest and Query service metrics.

## Using the OpenTelemetry Collector

For production workloads, use the [OpenTelemetry Collector](https://opentelemetry.io/docs/collector/) to forward data from your applications to IceGate:

```yaml
# otel-collector-config.yaml
exporters:
  otlp/icegate:
    endpoint: icegate-ingest:4317
    tls:
      insecure: true
    headers:
      X-Scope-OrgID: my-tenant

service:
  pipelines:
    logs:
      receivers: [otlp]
      exporters: [otlp/icegate]
    traces:
      receivers: [otlp]
      exporters: [otlp/icegate]
    metrics:
      receivers: [otlp]
      exporters: [otlp/icegate]
```

## Multi-Tenancy

IceGate isolates data by tenant using the `X-Scope-OrgID` header. Each tenant's data is physically partitioned.

```bash
# Ingest for tenant "team-a"
curl -X POST http://localhost:4318/v1/logs \
  -H "X-Scope-OrgID: team-a" \
  -H "Content-Type: application/json" \
  -d '...'

# Query only sees team-a's data
curl -G http://localhost:3100/loki/api/v1/query_range \
  --data-urlencode 'query={service_name="api"}' \
  -H "X-Scope-OrgID: team-a"
```

See [Multi-Tenancy](../guides/multi-tenancy.md) for details.

## Next Steps

- Learn [LogQL querying](../guides/querying.md) in depth
- Explore the [Loki API](../api-reference/loki.md) reference
- Configure [data ingestion](../guides/ingestion.md) pipelines
- Understand the [data model](../architecture/data-model.md)

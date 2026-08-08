---
title: Cross-Signal Correlation
description: Correlate logs, traces, and metrics across observability pillars in {{product_name}}
---

# Cross-Signal Correlation

This cookbook shows how to correlate data across logs, traces, and metrics in {{product_name}} to quickly move from an alert to a root cause.

{% note warning %}

This guide uses the Loki API (fully implemented) and the Tempo API (retrieval and search available; TraceQL supported, unimplemented features return `501`). The Prometheus API is NOT implemented — every route returns `501` except `/-/ready`; use LogQL metric queries as an alternative for log-based metrics.

{% endnote %}

## How Correlation Works

{{product_name}} stores all observability signals in Apache Iceberg tables with shared fields that enable cross-signal linking:

| Field | Present In | Purpose |
|-------|-----------|---------|
| `trace_id` | logs, spans | Links logs to the trace they belong to |
| `span_id` | logs, spans | Links logs to a specific span |
| `service_name` | logs, spans, metrics | Identifies the originating service |
| `tenant_id` | all tables | Isolates data per tenant |
| `timestamp` | all tables | Time correlation |

## Workflow: Alert → Logs → Traces → Root Cause

### 1. Detect an Issue via Log Metrics

Use LogQL to detect error spikes:

```bash
# Error rate per service over the last hour
curl -G http://localhost:3100/loki/api/v1/query_range \
  --data-urlencode 'query=sum by (service_name) (rate({severity_text="ERROR"}[5m]))' \
  --data-urlencode 'start=1704067200' \
  --data-urlencode 'end=1704070800' \
  --data-urlencode 'step=300' \
  -H "X-Scope-OrgID: my-tenant"
```

### 2. Investigate Error Logs

Drill into the failing service:

```bash
# Get error logs from the affected service
curl -G http://localhost:3100/loki/api/v1/query_range \
  --data-urlencode 'query={service_name="order-service", severity_text="ERROR"}' \
  --data-urlencode 'start=1704067200' \
  --data-urlencode 'end=1704070800' \
  --data-urlencode 'limit=50' \
  -H "X-Scope-OrgID: my-tenant"
```

The response includes log entries with `trace_id` in the attributes:

```json
{
  "streams": [{
    "stream": {
      "service_name": "order-service",
      "severity_text": "ERROR"
    },
    "values": [
      ["1704068100000000000", "Payment timeout for order ORD-789"],
      ["1704068200000000000", "Database connection pool exhausted"]
    ]
  }]
}
```

### 3. Find Logs with a Specific Trace ID

Search for all logs associated with a request:

```bash
# Find logs by trace ID
curl -G http://localhost:3100/loki/api/v1/query_range \
  --data-urlencode 'query={service_name=~".+"} |= "5B8EFFF798038103D269B633813FC60C"' \
  --data-urlencode 'start=1704067200' \
  --data-urlencode 'end=1704070800' \
  -H "X-Scope-OrgID: my-tenant"
```

This returns logs from **all services** that participated in the same trace — showing the complete request path.

### 4. Retrieve the Full Trace

Use the trace ID to get the complete span tree via the Tempo API:

```bash
curl http://localhost:3200/api/traces/5B8EFFF798038103D269B633813FC60C \
  -H "X-Scope-OrgID: my-tenant"
```

The response shows the request's journey through all services with timing for each span.

### 5. Find Slow Operations

Search for traces with high latency:

```bash
curl -G http://localhost:3200/api/search \
  --data-urlencode 'tags=service.name=order-service' \
  --data-urlencode 'minDuration=1s' \
  --data-urlencode 'limit=10' \
  -H "X-Scope-OrgID: my-tenant"
```

## Grafana Cross-Signal Navigation

### Link Logs → Traces

Configure Grafana to make trace IDs in log results clickable:

```yaml
# grafana/provisioning/datasources/icegate.yaml
apiVersion: 1
datasources:
  - name: IceGate Logs
    type: loki
    access: proxy
    url: http://icegate-query:3100
    jsonData:
      httpHeaderName1: X-Scope-OrgID
      derivedFields:
        - datasourceUid: icegate-tempo
          matcherRegex: '"trace_id":"([a-fA-F0-9]+)"'
          name: TraceID
          url: '$${__value.raw}'
    secureJsonData:
      httpHeaderValue1: my-tenant
    uid: icegate-loki

  - name: IceGate Traces
    type: tempo
    access: proxy
    url: http://icegate-query:3200
    jsonData:
      httpHeaderName1: X-Scope-OrgID
      tracesToLogs:
        datasourceUid: icegate-loki
        tags: ['service.name']
        mappedTags: [{ key: 'service.name', value: 'service_name' }]
        mapTagNamesEnabled: true
        filterByTraceID: true
    secureJsonData:
      httpHeaderValue1: my-tenant
    uid: icegate-tempo
```

With this configuration:

- In **Explore > Loki**: trace IDs in log lines become clickable links to the trace view
- In **Explore > Tempo**: each span shows a "Logs for this span" button that filters logs by trace and span ID

### Build a Correlation Dashboard

Create a dashboard with linked panels:

**Error rate panel** (Loki, Time series):

```logql
sum by (service_name) (rate({severity_text="ERROR"}[5m]))
```

**Error logs panel** (Loki, Logs):

```logql
{severity_text="ERROR"}
```

Enable derived fields for trace ID linking.

**Trace search panel** (Tempo, Table): Filter by service name and minimum duration.

## API-Level Correlation Patterns

### Find All Signals for a Request

Given a trace ID, retrieve data from both APIs:

```bash
# 1. Get the trace (all spans)
curl http://localhost:3200/api/traces/5B8EFFF798038103D269B633813FC60C \
  -H "X-Scope-OrgID: my-tenant"

# 2. Get all logs for this trace
curl -G http://localhost:3100/loki/api/v1/query_range \
  --data-urlencode 'query={service_name=~".+"} |= "5B8EFFF798038103D269B633813FC60C"' \
  --data-urlencode 'start=1704067200' \
  --data-urlencode 'end=1704070800' \
  -H "X-Scope-OrgID: my-tenant"
```

### Correlate by Time Window

When you don't have a trace ID, correlate by timestamp:

```bash
# 1. Find the error time window
curl -G http://localhost:3100/loki/api/v1/query_range \
  --data-urlencode 'query=count_over_time({severity_text="ERROR"}[1m])' \
  --data-urlencode 'start=1704067200' \
  --data-urlencode 'end=1704070800' \
  --data-urlencode 'step=60' \
  -H "X-Scope-OrgID: my-tenant"

# 2. Search traces in the same time window
curl -G http://localhost:3200/api/search \
  --data-urlencode 'tags=service.name=order-service' \
  --data-urlencode 'start=1704068100' \
  --data-urlencode 'end=1704068200' \
  -H "X-Scope-OrgID: my-tenant"
```

### Correlate by Service

Find all signals for a specific service:

```bash
# Logs from the service
curl -G http://localhost:3100/loki/api/v1/query_range \
  --data-urlencode 'query={service_name="order-service"}' \
  --data-urlencode 'start=1704067200' \
  --data-urlencode 'end=1704070800' \
  -H "X-Scope-OrgID: my-tenant"

# Traces from the service
curl -G http://localhost:3200/api/search \
  --data-urlencode 'tags=service.name=order-service' \
  --data-urlencode 'start=1704067200' \
  --data-urlencode 'end=1704070800' \
  -H "X-Scope-OrgID: my-tenant"

# Labels for the service
curl http://localhost:3100/loki/api/v1/label/service_name/values \
  -H "X-Scope-OrgID: my-tenant"
```

## Best Practices

1. **Always include trace context in logs**: Configure OpenTelemetry SDKs to inject `trace_id` and `span_id` into log records automatically
2. **Use consistent service names**: The `service.name` resource attribute should match across logs, traces, and metrics for the same service
3. **Set timestamp ranges**: Always specify `start` and `end` in queries to enable Iceberg partition pruning
4. **Start broad, then narrow**: Begin with error rate metrics, filter to specific error logs, then follow trace IDs to the root cause

## Next Steps

- Set up [centralized logging](centralized-logging.md) for your microservices
- Configure [end-to-end tracing](traces-end-to-end.md) with instrumentation examples
- Review the [data model](../architecture/data-model.md) for field details

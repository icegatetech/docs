---
title: Data Ingestion
description: Ingest logs, traces, and metrics into IceGate
---

# Data Ingestion

IceGate accepts observability data via the OpenTelemetry Protocol (OTLP). This guide covers how to ingest logs, traces, and metrics.

## Supported Protocols

| Protocol | Port | Description |
|----------|------|-------------|
| OTLP HTTP | 4318 | HTTP/JSON or HTTP/Protobuf |
| OTLP gRPC | 4317 | gRPC/Protobuf |

## Ingesting Logs

### OTLP HTTP

Send logs using the OTLP HTTP endpoint:

```bash
curl -X POST http://localhost:4318/v1/logs \
  -H "Content-Type: application/json" \
  -H "X-Scope-OrgID: my-tenant" \
  -d '{
    "resourceLogs": [{
      "resource": {
        "attributes": [
          {"key": "service.name", "value": {"stringValue": "api-service"}}
        ]
      },
      "scopeLogs": [{
        "logRecords": [{
          "timeUnixNano": "1704067200000000000",
          "body": {"stringValue": "Request processed successfully"},
          "severityText": "INFO",
          "severityNumber": 9,
          "attributes": [
            {"key": "http.method", "value": {"stringValue": "GET"}},
            {"key": "http.status_code", "value": {"intValue": "200"}}
          ]
        }]
      }]
    }]
  }'
```

### Using OpenTelemetry SDKs

Configure your OpenTelemetry SDK to send logs to IceGate:

```python
# Python example
from opentelemetry.sdk._logs import LoggerProvider
from opentelemetry.sdk._logs.export import BatchLogRecordProcessor
from opentelemetry.exporter.otlp.proto.http._log_exporter import OTLPLogExporter

logger_provider = LoggerProvider()
logger_provider.add_log_record_processor(
    BatchLogRecordProcessor(
        OTLPLogExporter(
            endpoint="http://localhost:4318/v1/logs",
            headers={"X-Scope-OrgID": "my-tenant"}
        )
    )
)
```

## Ingesting Traces

Send distributed trace spans to IceGate:

```bash
curl -X POST http://localhost:4318/v1/traces \
  -H "Content-Type: application/json" \
  -H "X-Scope-OrgID: my-tenant" \
  -d '{
    "resourceSpans": [{
      "resource": {
        "attributes": [
          {"key": "service.name", "value": {"stringValue": "api-service"}}
        ]
      },
      "scopeSpans": [{
        "spans": [{
          "traceId": "5B8EFFF798038103D269B633813FC60C",
          "spanId": "EEE19B7EC3C1B174",
          "name": "GET /api/users",
          "kind": 2,
          "startTimeUnixNano": "1704067200000000000",
          "endTimeUnixNano": "1704067200100000000",
          "status": {"code": 1}
        }]
      }]
    }]
  }'
```

## Ingesting Metrics

Send metrics using OTLP:

```bash
curl -X POST http://localhost:4318/v1/metrics \
  -H "Content-Type: application/json" \
  -H "X-Scope-OrgID: my-tenant" \
  -d '{
    "resourceMetrics": [{
      "resource": {
        "attributes": [
          {"key": "service.name", "value": {"stringValue": "api-service"}}
        ]
      },
      "scopeMetrics": [{
        "metrics": [{
          "name": "http_requests_total",
          "sum": {
            "dataPoints": [{
              "startTimeUnixNano": "1704067200000000000",
              "timeUnixNano": "1704067260000000000",
              "asInt": "1234"
            }],
            "aggregationTemporality": 2,
            "isMonotonic": true
          }
        }]
      }]
    }]
  }'
```

## Tenant Identification

IceGate is multi-tenant. Specify the tenant using the `X-Scope-OrgID` header:

```bash
curl -X POST http://localhost:4318/v1/logs \
  -H "X-Scope-OrgID: tenant-123" \
  -H "Content-Type: application/json" \
  -d '...'
```

## Data Flow

1. **Ingest Service** receives OTLP data
2. Data is written to **WAL** (Write-Ahead Log) as Parquet files
3. **Maintain Service** compacts WAL into optimized Iceberg tables
4. **Query Service** reads from both WAL (real-time) and Iceberg (historical)

## Delivery Guarantees

IceGate provides **exactly-once delivery** semantics:

- Data is durably written to object storage before acknowledgment
- Idempotent writes prevent duplicates
- WAL ensures no data loss during compaction

## Next Steps

- Learn how to [Query Data](querying.md)
- Set up [Multi-Tenancy](multi-tenancy.md)
- Explore the [Loki API](../api-reference/loki.md) for querying

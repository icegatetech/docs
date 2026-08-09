---
title: OTLP Ingestion API
description: OpenTelemetry Protocol ingestion for {{product_name}} over HTTP and gRPC - endpoints, SDK setup, authentication, error responses, and load testing.
---

# OTLP Ingestion API

{{product_name}} accepts observability data via the OpenTelemetry Protocol (OTLP). Both HTTP and gRPC transports are supported.

## Protocols

| Protocol | Default Port | Content Types |
|----------|-------------|---------------|
| HTTP | 4318 | `application/x-protobuf`, `application/json` |
| gRPC | 4317 | Protobuf (standard gRPC) |

## Authentication

All requests require the `X-Scope-OrgID` header (case-insensitive) for tenant identification:

```
X-Scope-OrgID: my-tenant
```

**Tenant ID rules:**

- Allowed characters: ASCII alphanumeric, hyphens (`-`), underscores (`_`)
- Default: `default` (when header is missing or invalid)

## HTTP Endpoints

### Ingest Logs

**Endpoint:** `POST /v1/logs`

Ingest OpenTelemetry log records.

**Headers:**

| Header | Required | Description |
|--------|----------|-------------|
| `Content-Type` | No | `application/x-protobuf` (default) or `application/json` |
| `X-Scope-OrgID` | No | Tenant identifier (default: `default`) |

**Example (JSON):**

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

**Example (Protobuf):**

```bash
# Using an OpenTelemetry SDK or collector with protobuf encoding
curl -X POST http://localhost:4318/v1/logs \
  -H "Content-Type: application/x-protobuf" \
  -H "X-Scope-OrgID: my-tenant" \
  --data-binary @logs.pb
```

**Response (200 OK):**

```json
{
  "partialSuccess": {
    "rejectedLogRecords": 0,
    "errorMessage": ""
  }
}
```

### Ingest Traces

**Endpoint:** `POST /v1/traces`

Ingest OpenTelemetry trace spans.

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

### Ingest Metrics

**Endpoint:** `POST /v1/metrics`

Ingest OpenTelemetry metrics.

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

### Health Check

**Endpoint:** `GET /health`

```bash
curl http://localhost:4318/health
```

**Response:**

```json
{"status": "healthy"}
```

## gRPC Services

The gRPC server implements the standard OpenTelemetry Collector services on port 4317.

### Services

| Service | Method | Description |
|---------|--------|-------------|
| `opentelemetry.proto.collector.logs.v1.LogsService` | `Export` | Ingest log records |
| `opentelemetry.proto.collector.trace.v1.TraceService` | `Export` | Ingest trace spans |
| `opentelemetry.proto.collector.metrics.v1.MetricsService` | `Export` | Ingest metrics |

### Tenant Metadata

Pass the tenant ID as gRPC metadata:

```
x-scope-orgid: my-tenant
```

### Example with grpcurl

```bash
# Check available services
grpcurl -plaintext localhost:4317 list

# Send logs (requires proto file)
grpcurl -plaintext \
  -H "x-scope-orgid: my-tenant" \
  -d '{"resourceLogs": [...]}' \
  localhost:4317 \
  opentelemetry.proto.collector.logs.v1.LogsService/Export
```

## Using OpenTelemetry SDKs

### Python

```python
from opentelemetry.sdk._logs import LoggerProvider
from opentelemetry.sdk._logs.export import BatchLogRecordProcessor
from opentelemetry.exporter.otlp.proto.grpc._log_exporter import OTLPLogExporter

provider = LoggerProvider()
provider.add_log_record_processor(
    BatchLogRecordProcessor(
        OTLPLogExporter(
            endpoint="localhost:4317",
            headers={"X-Scope-OrgID": "my-tenant"},
            insecure=True,
        )
    )
)
```

### Go

```go
import "go.opentelemetry.io/otel/exporters/otlp/otlplog/otlploggrpc"

exporter, _ := otlploggrpc.New(ctx,
    otlploggrpc.WithEndpoint("localhost:4317"),
    otlploggrpc.WithInsecure(),
    otlploggrpc.WithHeaders(map[string]string{
        "X-Scope-OrgID": "my-tenant",
    }),
)
```

### OpenTelemetry Collector

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

## Error Responses

### HTTP Errors

| HTTP Status | Error Type | Description |
|-------------|-----------|-------------|
| 400 | Bad Request | Invalid OTLP payload or encoding |
| 408 | Request Timeout | Request cancelled |
| 500 | Internal Server Error | Storage or processing failure |
| 501 | Not Implemented | Endpoint not yet implemented |
| 503 | Service Unavailable | WAL queue full or storage unreachable |

### gRPC Status Codes

| gRPC Code | Description |
|-----------|-------------|
| `INVALID_ARGUMENT` | Invalid payload or encoding |
| `UNIMPLEMENTED` | Service not yet implemented |
| `INTERNAL` | Storage or processing failure |
| `CANCELLED` | Request cancelled |
| `UNAVAILABLE` | WAL queue full or storage unreachable |

## Load Testing with IceGen

[IceGen](https://github.com/icegatetech/icegen) is a high-performance OpenTelemetry log generator for testing {{product_name}} ingestion.

### Install

```bash
git clone https://github.com/icegatetech/icegen.git
cd icegen
cargo build --release
```

### Usage

```bash
# Send 100 logs via HTTP JSON
otel-log-generator otel \
  --endpoint http://localhost:4318/v1/logs \
  --count 100

# Send via gRPC with 8 tenants and 20 concurrent workers
otel-log-generator otel \
  --endpoint http://localhost:4317 \
  --transport grpc \
  --tenant-count 8 \
  --count 1000 \
  --concurrency 20

# Continuous mode with protobuf encoding
otel-log-generator otel \
  --endpoint http://localhost:4318/v1/logs \
  --use-protobuf \
  --continuous \
  --message-interval-ms 100 \
  --concurrency 10

# Aggregated messages (5 records per request)
otel-log-generator otel \
  --endpoint http://localhost:4318/v1/logs \
  --records-per-message 5 \
  --count 100

# Test error handling with 10% invalid records
otel-log-generator otel \
  --endpoint http://localhost:4318/v1/logs \
  --invalid-record-percent 10.0 \
  --count 100
```

### IceGen Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `--endpoint` | | OTLP endpoint URL |
| `--transport` | `http` | Transport: `http` or `grpc` |
| `--use-protobuf` | `false` | Use protobuf encoding (HTTP only) |
| `--count` | `1` | Number of messages to send |
| `--concurrency` | `1` | Number of concurrent workers |
| `--message-interval-ms` | `0` | Delay between messages (ms) |
| `--records-per-message` | `1` | Log records per message |
| `--continuous` | `false` | Run continuously |
| `--tenant-id` | `default` | Tenant ID |
| `--tenant-count` | `1` | Number of random tenants |
| `--invalid-record-percent` | `0.0` | Percentage of invalid records |

## Data Flow

1. Client sends OTLP data to Ingest service
2. Ingest validates and transforms data to Arrow RecordBatch
3. Records sorted into WAL row groups by partition keys
4. Data written to WAL (Parquet on object storage) via bounded queue
5. Acknowledgment sent to client (exactly-once delivery)
6. Shift process compacts WAL into Iceberg tables asynchronously

## Next Steps

- Query ingested data with the [Loki API](loki.md)
- Learn about the [Data Model](../architecture/data-model.md)
- Configure [ingestion](../guides/ingestion.md) pipelines

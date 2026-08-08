---
title: End-to-End Distributed Tracing
description: Instrument services, send traces to {{product_name}}, and query them via the Tempo API
---

# End-to-End Distributed Tracing

This cookbook walks through instrumenting services with OpenTelemetry, sending trace data to {{product_name}} via OTLP, and retrieving traces via the Tempo-compatible API.

{% note warning %}

The Tempo-compatible API implements a subset of Tempo's API: trace retrieval by ID, TraceQL search via `/api/search`, and tag discovery (v1 and v2). TraceQL features that are not yet implemented return `501 Not Implemented` rather than a wrong result. See the [Tempo API reference](../api-reference/tempo.md) for the endpoints served today.

{% endnote %}

## Architecture

```
┌──────────────┐         ┌──────────────┐
│  Frontend    │──HTTP──▶│  API Gateway │
│  (browser)   │         │  (service A) │
└──────────────┘         └──────┬───────┘
                                │ gRPC
                    ┌───────────┴───────────┐
                    ▼                       ▼
           ┌──────────────┐       ┌──────────────┐
           │  Order Svc   │       │  User Svc    │
           │  (service B) │       │  (service C) │
           └──────┬───────┘       └──────────────┘
                  │
                  ▼ OTLP (4317)
           ┌──────────────┐
           │  IceGate     │
           │  Ingest      │
           └──────┬───────┘
                  ▼
           ┌──────────────┐
           │  IceGate     │
           │  Query       │◄── Tempo API (3200)
           └──────────────┘
```

## Step 1: Instrument Services

### Python (OpenTelemetry SDK)

```python
from opentelemetry import trace
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from opentelemetry.exporter.otlp.proto.grpc.trace_exporter import OTLPSpanExporter
from opentelemetry.sdk.resources import Resource

# Configure tracing
resource = Resource.create({
    "service.name": "order-service",
    "service.version": "1.0.0",
})

provider = TracerProvider(resource=resource)
provider.add_span_processor(
    BatchSpanProcessor(
        OTLPSpanExporter(
            endpoint="icegate-ingest:4317",
            headers={"X-Scope-OrgID": "my-tenant"},
            insecure=True,
        )
    )
)
trace.set_tracer_provider(provider)
tracer = trace.get_tracer("order-service")

# Create spans
with tracer.start_as_current_span("process-order") as span:
    span.set_attribute("order.id", "ORD-12345")
    span.set_attribute("http.method", "POST")
    span.set_attribute("http.status_code", 200)
    # ... business logic ...
```

### Go (OpenTelemetry SDK)

```go
import (
    "go.opentelemetry.io/otel"
    "go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracegrpc"
    "go.opentelemetry.io/otel/sdk/resource"
    sdktrace "go.opentelemetry.io/otel/sdk/trace"
    semconv "go.opentelemetry.io/otel/semconv/v1.4.0"
)

exporter, _ := otlptracegrpc.New(ctx,
    otlptracegrpc.WithEndpoint("icegate-ingest:4317"),
    otlptracegrpc.WithInsecure(),
    otlptracegrpc.WithHeaders(map[string]string{
        "X-Scope-OrgID": "my-tenant",
    }),
)

res := resource.NewWithAttributes(
    semconv.SchemaURL,
    semconv.ServiceNameKey.String("api-gateway"),
)

tp := sdktrace.NewTracerProvider(
    sdktrace.WithBatcher(exporter),
    sdktrace.WithResource(res),
)
otel.SetTracerProvider(tp)
```

### OpenTelemetry Collector

For production, route traces through the OpenTelemetry Collector:

```yaml
# otel-collector-config.yaml
receivers:
  otlp:
    protocols:
      grpc:
        endpoint: 0.0.0.0:4317

processors:
  batch:
    send_batch_size: 512
    timeout: 5s

exporters:
  otlp/icegate:
    endpoint: icegate-ingest:4317
    tls:
      insecure: true
    headers:
      X-Scope-OrgID: my-tenant

service:
  pipelines:
    traces:
      receivers: [otlp]
      processors: [batch]
      exporters: [otlp/icegate]
```

## Step 2: Send Test Traces

Send a sample trace via curl to verify the setup:

```bash
curl -X POST http://localhost:4318/v1/traces \
  -H "Content-Type: application/json" \
  -H "X-Scope-OrgID: my-tenant" \
  -d '{
    "resourceSpans": [{
      "resource": {
        "attributes": [
          {"key": "service.name", "value": {"stringValue": "api-gateway"}}
        ]
      },
      "scopeSpans": [{
        "spans": [
          {
            "traceId": "5B8EFFF798038103D269B633813FC60C",
            "spanId": "EEE19B7EC3C1B174",
            "name": "GET /api/orders",
            "kind": 2,
            "startTimeUnixNano": "1704067200000000000",
            "endTimeUnixNano": "1704067200150000000",
            "status": {"code": 1},
            "attributes": [
              {"key": "http.method", "value": {"stringValue": "GET"}},
              {"key": "http.status_code", "value": {"intValue": "200"}},
              {"key": "http.url", "value": {"stringValue": "/api/orders"}}
            ]
          },
          {
            "traceId": "5B8EFFF798038103D269B633813FC60C",
            "spanId": "AABB19B7EC3C1B22",
            "parentSpanId": "EEE19B7EC3C1B174",
            "name": "SELECT orders",
            "kind": 3,
            "startTimeUnixNano": "1704067200050000000",
            "endTimeUnixNano": "1704067200120000000",
            "status": {"code": 1},
            "attributes": [
              {"key": "db.system", "value": {"stringValue": "postgresql"}},
              {"key": "db.statement", "value": {"stringValue": "SELECT * FROM orders WHERE user_id = $1"}}
            ]
          }
        ]
      }]
    }]
  }'
```

## Step 3: Retrieve Traces

### Get a Trace by ID

```bash
curl http://localhost:3200/api/traces/5B8EFFF798038103D269B633813FC60C \
  -H "X-Scope-OrgID: my-tenant"
```

Response contains all spans for the trace:

```json
{
  "batches": [
    {
      "resource": {
        "attributes": [
          {"key": "service.name", "value": {"stringValue": "api-gateway"}}
        ]
      },
      "scopeSpans": [
        {
          "spans": [
            {
              "traceId": "5B8EFFF798038103D269B633813FC60C",
              "spanId": "EEE19B7EC3C1B174",
              "name": "GET /api/orders",
              "kind": 2,
              "startTimeUnixNano": "1704067200000000000",
              "endTimeUnixNano": "1704067200150000000",
              "status": {"code": 1}
            }
          ]
        }
      ]
    }
  ]
}
```

### Search Traces by Service

```bash
curl -G http://localhost:3200/api/search \
  --data-urlencode 'tags=service.name=api-gateway' \
  --data-urlencode 'limit=10' \
  -H "X-Scope-OrgID: my-tenant"
```

### Search by Duration

Find slow traces (>500ms):

```bash
curl -G http://localhost:3200/api/search \
  --data-urlencode 'tags=service.name=api-gateway' \
  --data-urlencode 'minDuration=500ms' \
  --data-urlencode 'limit=10' \
  -H "X-Scope-OrgID: my-tenant"
```

### List Available Tags

```bash
curl http://localhost:3200/api/search/tags \
  -H "X-Scope-OrgID: my-tenant"
```

### Get Tag Values

```bash
curl http://localhost:3200/api/search/tag/service.name/values \
  -H "X-Scope-OrgID: my-tenant"
```

## Step 4: View in Grafana

Configure the Tempo data source:

```yaml
# grafana/provisioning/datasources/icegate-tempo.yaml
apiVersion: 1
datasources:
  - name: IceGate Traces
    type: tempo
    access: proxy
    url: http://icegate-query:3200
    jsonData:
      httpHeaderName1: X-Scope-OrgID
    secureJsonData:
      httpHeaderValue1: my-tenant
```

Then in Grafana:

1. Go to **Explore** > select **{{product_name}} Traces**
2. Enter a service name in the search field
3. Click a trace to view its span waterfall diagram
4. Inspect individual spans for attributes and timing

See [Grafana Integration](../guides/grafana-integration.md) for cross-signal linking between traces and logs.

## Span Data Model

Spans stored in {{product_name}} include:

| Field | Type | Description |
|-------|------|-------------|
| `trace_id` | bytes | 16-byte trace identifier |
| `span_id` | bytes | 8-byte span identifier |
| `parent_span_id` | bytes | Parent span (empty for root) |
| `name` | string | Operation name |
| `kind` | int | 0=Unspecified, 1=Internal, 2=Server, 3=Client, 4=Producer, 5=Consumer |
| `start_timestamp` | timestamp | Span start time |
| `end_timestamp` | timestamp | Span end time |
| `duration_micros` | long | Duration in microseconds |
| `status_code` | int | 0=Unset, 1=OK, 2=Error |
| `attributes` | map | Merged resource/scope/span attributes |

## Next Steps

- Set up [cross-signal correlation](observability-correlation.md) to link traces with logs
- Configure [centralized logging](centralized-logging.md) alongside traces
- Review the [Tempo API reference](../api-reference/tempo.md) for all endpoints

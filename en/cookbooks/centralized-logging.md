---
title: Centralized Logging for Microservices
description: Set up centralized log collection from microservices into IceGate
---

# Centralized Logging for Microservices

This cookbook walks through setting up centralized log collection from multiple microservices into {{product_name}} using the OpenTelemetry Collector.

## Architecture

```
┌──────────────┐  ┌──────────────┐  ┌──────────────┐
│  Service A   │  │  Service B   │  │  Service C   │
│  (Python)    │  │  (Go)        │  │  (Node.js)   │
└──────┬───────┘  └──────┬───────┘  └──────┬───────┘
       │                 │                 │
       │    OTLP gRPC    │    OTLP gRPC    │
       ▼                 ▼                 ▼
┌─────────────────────────────────────────────────┐
│           OpenTelemetry Collector                │
│   receivers: [otlp]                              │
│   processors: [batch, resource]                  │
│   exporters: [otlp/icegate]                      │
└──────────────────────┬──────────────────────────┘
                       │  OTLP gRPC (port 4317)
                       ▼
              ┌────────────────┐
              │  IceGate       │
              │  Ingest (4317) │
              └────────┬───────┘
                       │  WAL → Shift
                       ▼
              ┌────────────────┐
              │  IceGate       │
              │  Query (3100)  │◄── Grafana
              └────────────────┘
```

## Step 1: Deploy the OpenTelemetry Collector

The Collector acts as a central aggregation point, decoupling your services from {{product_name}}.

```yaml
# otel-collector-config.yaml
receivers:
  otlp:
    protocols:
      grpc:
        endpoint: 0.0.0.0:4317
      http:
        endpoint: 0.0.0.0:4318

processors:
  batch:
    send_batch_size: 1024
    send_batch_max_size: 2048
    timeout: 5s
  resource:
    attributes:
      - key: environment
        value: production
        action: upsert

exporters:
  otlp/icegate:
    endpoint: icegate-ingest:4317
    tls:
      insecure: true
    headers:
      X-Scope-OrgID: my-tenant
    retry_on_failure:
      enabled: true
      initial_interval: 1s
      max_interval: 30s
    sending_queue:
      enabled: true
      num_consumers: 10
      queue_size: 1000

service:
  pipelines:
    logs:
      receivers: [otlp]
      processors: [batch, resource]
      exporters: [otlp/icegate]
    traces:
      receivers: [otlp]
      processors: [batch, resource]
      exporters: [otlp/icegate]
```

### Deploy with Docker Compose

```yaml
# docker-compose.yml
services:
  otel-collector:
    image: otel/opentelemetry-collector-contrib:latest
    command: ["--config=/etc/otel/config.yaml"]
    volumes:
      - ./otel-collector-config.yaml:/etc/otel/config.yaml
    ports:
      - "4317:4317"   # OTLP gRPC
      - "4318:4318"   # OTLP HTTP
```

## Step 2: Instrument Your Services

### Python (with OpenTelemetry SDK)

```python
import logging
from opentelemetry.sdk._logs import LoggerProvider
from opentelemetry.sdk._logs.export import BatchLogRecordProcessor
from opentelemetry.exporter.otlp.proto.grpc._log_exporter import OTLPLogExporter
from opentelemetry.sdk.resources import Resource

# Configure OpenTelemetry
resource = Resource.create({
    "service.name": "order-service",
    "service.version": "1.2.0",
    "deployment.environment": "production",
})

provider = LoggerProvider(resource=resource)
provider.add_log_record_processor(
    BatchLogRecordProcessor(
        OTLPLogExporter(
            endpoint="otel-collector:4317",
            insecure=True,
        )
    )
)

# Use standard Python logging — bridged to OTLP
logger = logging.getLogger("order-service")
logger.info("Order created", extra={"order.id": "ORD-12345", "user.id": "usr-42"})
```

### Go (with OpenTelemetry SDK)

```go
import (
    "go.opentelemetry.io/otel/exporters/otlp/otlplog/otlploggrpc"
    "go.opentelemetry.io/otel/sdk/resource"
    semconv "go.opentelemetry.io/otel/semconv/v1.4.0"
)

res := resource.NewWithAttributes(
    semconv.SchemaURL,
    semconv.ServiceNameKey.String("payment-service"),
    semconv.ServiceVersionKey.String("2.0.1"),
)

exporter, _ := otlploggrpc.New(ctx,
    otlploggrpc.WithEndpoint("otel-collector:4317"),
    otlploggrpc.WithInsecure(),
)
```

### Direct Ingestion (without Collector)

For simple setups, send logs directly to {{product_name}}:

```bash
curl -X POST http://localhost:4318/v1/logs \
  -H "Content-Type: application/json" \
  -H "X-Scope-OrgID: my-tenant" \
  -d '{
    "resourceLogs": [{
      "resource": {
        "attributes": [
          {"key": "service.name", "value": {"stringValue": "order-service"}},
          {"key": "deployment.environment", "value": {"stringValue": "production"}}
        ]
      },
      "scopeLogs": [{
        "logRecords": [{
          "timeUnixNano": "1704067200000000000",
          "body": {"stringValue": "Order ORD-12345 created for user usr-42"},
          "severityText": "INFO",
          "severityNumber": 9,
          "attributes": [
            {"key": "order.id", "value": {"stringValue": "ORD-12345"}},
            {"key": "user.id", "value": {"stringValue": "usr-42"}}
          ]
        }]
      }]
    }]
  }'
```

## Step 3: Query Logs Across Services

### Find Errors Across All Services

```bash
curl -G http://localhost:3100/loki/api/v1/query_range \
  --data-urlencode 'query={severity_text="ERROR"}' \
  --data-urlencode 'start=1704067200' \
  --data-urlencode 'end=1704153600' \
  --data-urlencode 'limit=100' \
  -H "X-Scope-OrgID: my-tenant"
```

### Filter by Service

```bash
curl -G http://localhost:3100/loki/api/v1/query_range \
  --data-urlencode 'query={service_name="order-service"} |= "error"' \
  --data-urlencode 'start=1704067200' \
  --data-urlencode 'end=1704153600' \
  -H "X-Scope-OrgID: my-tenant"
```

### Error Rate by Service

```bash
curl -G http://localhost:3100/loki/api/v1/query_range \
  --data-urlencode 'query=sum by (service_name) (rate({severity_text="ERROR"}[5m]))' \
  --data-urlencode 'start=1704067200' \
  --data-urlencode 'end=1704153600' \
  --data-urlencode 'step=300' \
  -H "X-Scope-OrgID: my-tenant"
```

### Search by Custom Attribute

```bash
curl -G http://localhost:3100/loki/api/v1/query_range \
  --data-urlencode 'query={service_name="order-service"} |= "ORD-12345"' \
  --data-urlencode 'start=1704067200' \
  --data-urlencode 'end=1704153600' \
  -H "X-Scope-OrgID: my-tenant"
```

### List All Services Sending Logs

```bash
curl http://localhost:3100/loki/api/v1/label/service_name/values \
  -H "X-Scope-OrgID: my-tenant"
```

## Step 4: Set Up Grafana

Add {{product_name}} as a Loki data source in Grafana:

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
    secureJsonData:
      httpHeaderValue1: my-tenant
    isDefault: true
```

See [Grafana Integration](../guides/grafana-integration.md) for dashboards and advanced configuration.

## Step 5: Per-Team Isolation

Use `X-Scope-OrgID` to isolate logs by team or environment:

```yaml
# Team A collector config
exporters:
  otlp/icegate:
    endpoint: icegate-ingest:4317
    tls:
      insecure: true
    headers:
      X-Scope-OrgID: team-platform

# Team B collector config
exporters:
  otlp/icegate:
    endpoint: icegate-ingest:4317
    tls:
      insecure: true
    headers:
      X-Scope-OrgID: team-backend
```

Each team queries only their own data. See [Multi-Tenancy](../guides/multi-tenancy.md) for details.

## Next Steps

- Add [distributed tracing](traces-end-to-end.md) to correlate logs with traces
- Set up [cross-signal correlation](observability-correlation.md) between logs and traces
- Configure [data retention](../guides/data-retention.md) policies

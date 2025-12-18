---
title: Tempo API Reference
description: Tempo-compatible HTTP API endpoints
---

# Tempo API Reference

IceGate provides a Tempo-compatible HTTP API for querying distributed traces.

## Base URL

```
http://localhost:3200
```

## Authentication

All requests require the `X-Scope-OrgID` header for tenant identification:

```
X-Scope-OrgID: my-tenant
```

## Implementation Status

{% note warning %}

The Tempo API is currently under development. Basic trace retrieval is available but TraceQL support is planned for future releases.

{% endnote %}

## Endpoints

### Get Trace by ID

Retrieve a complete trace by its trace ID.

**Endpoint:** `GET /api/traces/{traceID}`

**Parameters:**

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `traceID` | string | Yes | 32-character hex trace ID |

**Example:**

```bash
curl http://localhost:3200/api/traces/5B8EFFF798038103D269B633813FC60C \
  -H "X-Scope-OrgID: my-tenant"
```

**Response:**

```json
{
  "batches": [
    {
      "resource": {
        "attributes": [
          {"key": "service.name", "value": {"stringValue": "api-service"}}
        ]
      },
      "scopeSpans": [
        {
          "spans": [
            {
              "traceId": "5B8EFFF798038103D269B633813FC60C",
              "spanId": "EEE19B7EC3C1B174",
              "name": "GET /api/users",
              "kind": 2,
              "startTimeUnixNano": "1704067200000000000",
              "endTimeUnixNano": "1704067200100000000",
              "status": {"code": 1}
            }
          ]
        }
      ]
    }
  ]
}
```

### Search Traces

Search for traces matching criteria.

**Endpoint:** `GET /api/search`

**Parameters:**

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `tags` | string | No | Tag filter (e.g., `service.name=api`) |
| `minDuration` | duration | No | Minimum span duration |
| `maxDuration` | duration | No | Maximum span duration |
| `limit` | int | No | Maximum results (default: 20) |
| `start` | int | No | Start timestamp (Unix seconds) |
| `end` | int | No | End timestamp (Unix seconds) |

**Example:**

```bash
curl -G http://localhost:3200/api/search \
  --data-urlencode 'tags=service.name=api-service' \
  --data-urlencode 'minDuration=100ms' \
  --data-urlencode 'limit=10' \
  -H "X-Scope-OrgID: my-tenant"
```

### Search Tags

Get available tag names for search.

**Endpoint:** `GET /api/search/tags`

**Example:**

```bash
curl http://localhost:3200/api/search/tags \
  -H "X-Scope-OrgID: my-tenant"
```

### Search Tag Values

Get values for a specific tag.

**Endpoint:** `GET /api/search/tag/{tag}/values`

**Example:**

```bash
curl http://localhost:3200/api/search/tag/service.name/values \
  -H "X-Scope-OrgID: my-tenant"
```

## Span Data Model

Spans stored in IceGate include:

| Field | Type | Description |
|-------|------|-------------|
| `trace_id` | bytes | 16-byte trace identifier |
| `span_id` | bytes | 8-byte span identifier |
| `parent_span_id` | bytes | Parent span (if any) |
| `name` | string | Operation name |
| `kind` | int | SpanKind (0=Unspecified, 1=Internal, 2=Server, 3=Client, 4=Producer, 5=Consumer) |
| `start_timestamp` | timestamp | Span start time |
| `end_timestamp` | timestamp | Span end time |
| `duration_micros` | long | Duration in microseconds |
| `status_code` | int | Status (0=Unset, 1=OK, 2=Error) |
| `attributes` | map | Merged resource/scope/span attributes |
| `events` | array | Span events |
| `links` | array | Links to other spans |

## Next Steps

- Learn about [Data Ingestion](../guides/ingestion.md)
- Explore the [Loki API](loki.md) for logs
- See [Prometheus API](prometheus.md) for metrics

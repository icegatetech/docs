---
title: Loki API Reference
description: Loki-compatible HTTP API endpoints
---

# Loki API Reference

IceGate provides a Loki-compatible HTTP API for querying logs.

## Base URL

```
http://localhost:3100
```

## Authentication

All requests require the `X-Scope-OrgID` header for tenant identification:

```
X-Scope-OrgID: my-tenant
```

## Endpoints

### Query Range

Query logs or metrics over a time range.

**Endpoint:** `GET /loki/api/v1/query_range`

**Parameters:**

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `query` | string | Yes | LogQL query |
| `start` | int | Yes | Start timestamp (Unix seconds or nanoseconds) |
| `end` | int | Yes | End timestamp (Unix seconds or nanoseconds) |
| `limit` | int | No | Maximum number of entries (default: 100) |
| `step` | duration | No | Query resolution step (e.g., "5m") |
| `direction` | string | No | `forward` or `backward` (default: backward) |

**Example:**

```bash
curl -G http://localhost:3100/loki/api/v1/query_range \
  --data-urlencode 'query={service_name="api-service"}' \
  --data-urlencode 'start=1704067200' \
  --data-urlencode 'end=1704153600' \
  --data-urlencode 'limit=1000' \
  -H "X-Scope-OrgID: my-tenant"
```

**Response (Log Query):**

```json
{
  "status": "success",
  "data": {
    "resultType": "streams",
    "result": [
      {
        "stream": {
          "service_name": "api-service",
          "severity_text": "INFO"
        },
        "values": [
          ["1704067200000000000", "Request processed successfully"]
        ]
      }
    ]
  }
}
```

**Response (Metric Query):**

```json
{
  "status": "success",
  "data": {
    "resultType": "matrix",
    "result": [
      {
        "metric": {
          "service_name": "api-service"
        },
        "values": [
          [1704067200, "42"],
          [1704067500, "38"]
        ]
      }
    ]
  }
}
```

### Labels

Get all label names.

**Endpoint:** `GET /loki/api/v1/labels`

**Parameters:**

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `start` | int | No | Start timestamp |
| `end` | int | No | End timestamp |

**Example:**

```bash
curl http://localhost:3100/loki/api/v1/labels \
  -H "X-Scope-OrgID: my-tenant"
```

**Response:**

```json
{
  "status": "success",
  "data": [
    "service_name",
    "severity_text",
    "trace_id"
  ]
}
```

### Label Values

Get values for a specific label.

**Endpoint:** `GET /loki/api/v1/label/{name}/values`

**Parameters:**

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `start` | int | No | Start timestamp |
| `end` | int | No | End timestamp |

**Example:**

```bash
curl http://localhost:3100/loki/api/v1/label/service_name/values \
  -H "X-Scope-OrgID: my-tenant"
```

**Response:**

```json
{
  "status": "success",
  "data": [
    "api-service",
    "worker-service",
    "gateway"
  ]
}
```

### Series

Get label sets matching selectors.

**Endpoint:** `GET /loki/api/v1/series`

**Parameters:**

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `match[]` | string | Yes | Log stream selector(s) |
| `start` | int | No | Start timestamp |
| `end` | int | No | End timestamp |

**Example:**

```bash
curl -G http://localhost:3100/loki/api/v1/series \
  --data-urlencode 'match[]={service_name=~"api-.*"}' \
  -H "X-Scope-OrgID: my-tenant"
```

**Response:**

```json
{
  "status": "success",
  "data": [
    {"service_name": "api-service", "severity_text": "INFO"},
    {"service_name": "api-gateway", "severity_text": "ERROR"}
  ]
}
```

### Explain

Get query execution plan (IceGate extension).

**Endpoint:** `GET /loki/api/v1/explain`

**Parameters:**

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `query` | string | Yes | LogQL query |

**Example:**

```bash
curl -G http://localhost:3100/loki/api/v1/explain \
  --data-urlencode 'query=count_over_time({service_name="api-service"}[5m])' \
  -H "X-Scope-OrgID: my-tenant"
```

### Health Check

**Endpoint:** `GET /ready`

**Response:**

```json
{"status": "ready"}
```

## Error Responses

All errors return a JSON response:

```json
{
  "status": "error",
  "errorType": "bad_data",
  "error": "invalid query syntax"
}
```

| Error Type | HTTP Status | Description |
|------------|-------------|-------------|
| `bad_data` | 400 | Invalid request or query |
| `not_implemented` | 501 | Feature not implemented |
| `internal` | 500 | Internal server error |

## Next Steps

- Learn [LogQL Querying](../guides/querying.md)
- Explore the [Prometheus API](prometheus.md)
- See [Tempo API](tempo.md) for traces

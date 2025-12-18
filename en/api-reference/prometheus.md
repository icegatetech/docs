---
title: Prometheus API Reference
description: Prometheus-compatible HTTP API endpoints
---

# Prometheus API Reference

IceGate provides a Prometheus-compatible HTTP API for querying metrics.

## Base URL

```
http://localhost:9090
```

## Authentication

All requests require the `X-Scope-OrgID` header for tenant identification:

```
X-Scope-OrgID: my-tenant
```

## Implementation Status

{% note warning %}

The Prometheus API is currently under development. Basic endpoints are available but full PromQL support is planned for future releases.

{% endnote %}

## Endpoints

### Query Range

Query metrics over a time range.

**Endpoint:** `GET /api/v1/query_range`

**Parameters:**

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `query` | string | Yes | PromQL query |
| `start` | float | Yes | Start timestamp (Unix seconds) |
| `end` | float | Yes | End timestamp (Unix seconds) |
| `step` | duration | Yes | Query resolution step |

**Example:**

```bash
curl -G http://localhost:9090/api/v1/query_range \
  --data-urlencode 'query=http_requests_total{service="api"}' \
  --data-urlencode 'start=1704067200' \
  --data-urlencode 'end=1704153600' \
  --data-urlencode 'step=60' \
  -H "X-Scope-OrgID: my-tenant"
```

### Labels

Get all label names.

**Endpoint:** `GET /api/v1/labels`

**Example:**

```bash
curl http://localhost:9090/api/v1/labels \
  -H "X-Scope-OrgID: my-tenant"
```

### Label Values

Get values for a specific label.

**Endpoint:** `GET /api/v1/label/{name}/values`

**Example:**

```bash
curl http://localhost:9090/api/v1/label/service_name/values \
  -H "X-Scope-OrgID: my-tenant"
```

### Series

Get series matching selectors.

**Endpoint:** `GET /api/v1/series`

**Parameters:**

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `match[]` | string | Yes | Series selector(s) |
| `start` | float | No | Start timestamp |
| `end` | float | No | End timestamp |

**Example:**

```bash
curl -G http://localhost:9090/api/v1/series \
  --data-urlencode 'match[]={__name__=~"http_.*"}' \
  -H "X-Scope-OrgID: my-tenant"
```

## Metric Types

IceGate stores all OpenTelemetry metric types:

| Metric Type | Description |
|-------------|-------------|
| `gauge` | Point-in-time values |
| `sum` | Cumulative or delta sums |
| `histogram` | Standard histograms with explicit bounds |
| `exponential_histogram` | Histograms with exponential buckets |
| `summary` | Pre-calculated quantiles |

## Next Steps

- Learn about [Data Ingestion](../guides/ingestion.md)
- Explore the [Loki API](loki.md) for logs
- See [Tempo API](tempo.md) for traces

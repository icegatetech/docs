---
title: Prometheus API Reference
description: Planned Prometheus-compatible HTTP API — not yet implemented
---

# Prometheus API Reference

{% note warning %}

**Not implemented yet.** The routes below are mounted on port 9090, but every one of them returns
`501 Not Implemented`; only `/-/ready` responds. This page documents the *planned* surface so that
integrators can see where it is heading — do not build against it yet.

For metrics queries today, use [Arrow Flight SQL](../guides/querying.md) against the same data.

{% endnote %}

This is the planned shape of {{product_name}}'s Prometheus®-compatible HTTP API for querying metrics. See
[Trademarks](../trademarks.md) for attribution.

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

None of these endpoints are implemented. Every one returns `501 Not Implemented`, including the metadata endpoints; only `/-/ready` responds. PromQL is not parsed at all yet.

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

{{product_name}} stores all OpenTelemetry metric types:

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

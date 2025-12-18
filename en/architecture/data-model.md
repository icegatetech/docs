---
title: Data Model
description: IceGate Iceberg table schemas for observability data
---

# Data Model

IceGate stores observability data in four Apache Iceberg tables: logs, spans, events, and metrics.

## Table Overview

| Table | Description | Primary Use Case |
|-------|-------------|------------------|
| `logs` | OpenTelemetry LogRecords | Application logging |
| `spans` | Distributed trace spans | Request tracing |
| `events` | Semantic events | Business events, alerts |
| `metrics` | All metric types | Performance monitoring |

## Common Design Patterns

### Multi-Tenancy

All tables use identity partitioning on `tenant_id`:

```sql
partitioning = ARRAY['tenant_id', 'account_id', 'day(timestamp)']
```

### Attributes Storage

Attributes are stored as `MAP(VARCHAR, VARCHAR)` merging:

- Resource attributes
- Scope attributes
- Record-level attributes

### Time Precision

All timestamps use microsecond precision with timezone:

```sql
TIMESTAMP(6) WITH TIME ZONE
```

### Compression

All tables use ZSTD compression for optimal size/speed balance.

## Logs Table

Based on OpenTelemetry LogRecord.

```sql
CREATE TABLE logs (
    tenant_id VARCHAR NOT NULL,
    account_id VARCHAR,
    service_name VARCHAR,

    timestamp TIMESTAMP(6) WITH TIME ZONE NOT NULL,
    observed_timestamp TIMESTAMP(6) WITH TIME ZONE NOT NULL,
    ingested_timestamp TIMESTAMP(6) WITH TIME ZONE NOT NULL,

    trace_id VARBINARY,    -- 16 bytes
    span_id VARBINARY,     -- 8 bytes

    severity_number INTEGER,
    severity_text VARCHAR,
    body VARCHAR,

    attributes MAP(VARCHAR, VARCHAR) NOT NULL,

    flags INTEGER,
    dropped_attributes_count INTEGER NOT NULL
)
```

**Sorting:** `service_name`, `timestamp DESC` (recent-first)

### Severity Levels

| Number | Text | Description |
|--------|------|-------------|
| 1-4 | TRACE | Detailed debugging |
| 5-8 | DEBUG | Debug information |
| 9-12 | INFO | Normal operations |
| 13-16 | WARN | Warning conditions |
| 17-20 | ERROR | Error conditions |
| 21-24 | FATAL | Critical failures |

## Spans Table

Based on OpenTelemetry Span with nested events and links.

```sql
CREATE TABLE spans (
    tenant_id VARCHAR NOT NULL,
    account_id VARCHAR,

    trace_id VARBINARY NOT NULL,    -- 16 bytes
    span_id VARBINARY NOT NULL,     -- 8 bytes
    parent_span_id VARBINARY,       -- 8 bytes

    timestamp TIMESTAMP(6) WITH TIME ZONE NOT NULL,
    end_timestamp TIMESTAMP(6) WITH TIME ZONE NOT NULL,
    ingested_timestamp TIMESTAMP(6) WITH TIME ZONE NOT NULL,
    duration_micros BIGINT NOT NULL,

    trace_state VARCHAR,
    name VARCHAR NOT NULL,
    kind INTEGER,
    status_code INTEGER,
    status_message VARCHAR,

    attributes MAP(VARCHAR, VARCHAR) NOT NULL,

    flags INTEGER,
    dropped_attributes_count INTEGER,
    dropped_events_count INTEGER,
    dropped_links_count INTEGER,

    events ARRAY(ROW(
        timestamp TIMESTAMP(6) WITH TIME ZONE,
        name VARCHAR,
        attributes MAP(VARCHAR, VARCHAR),
        dropped_attributes_count INTEGER
    )),

    links ARRAY(ROW(
        trace_id VARBINARY,
        span_id VARBINARY,
        trace_state VARCHAR,
        attributes MAP(VARCHAR, VARCHAR),
        dropped_attributes_count INTEGER,
        flags INTEGER
    ))
)
```

**Sorting:** `trace_id`, `timestamp` (group spans by trace)

### Span Kind

| Value | Name | Description |
|-------|------|-------------|
| 0 | UNSPECIFIED | Not specified |
| 1 | INTERNAL | Internal operation |
| 2 | SERVER | Server-side request |
| 3 | CLIENT | Client-side request |
| 4 | PRODUCER | Message producer |
| 5 | CONSUMER | Message consumer |

### Status Code

| Value | Name | Description |
|-------|------|-------------|
| 0 | UNSET | Status not set |
| 1 | OK | Operation successful |
| 2 | ERROR | Operation failed |

## Events Table

Semantic events extracted from logs.

```sql
CREATE TABLE events (
    tenant_id VARCHAR NOT NULL,
    account_id VARCHAR,
    service_name VARCHAR,

    timestamp TIMESTAMP(6) WITH TIME ZONE NOT NULL,
    observed_timestamp TIMESTAMP(6) WITH TIME ZONE NOT NULL,
    ingested_timestamp TIMESTAMP(6) WITH TIME ZONE NOT NULL,

    event_domain VARCHAR NOT NULL,
    event_name VARCHAR NOT NULL,

    trace_id VARBINARY,
    span_id VARBINARY,

    attributes MAP(VARCHAR, VARCHAR) NOT NULL
)
```

**Sorting:** `service_name`, `timestamp DESC`

Events follow OpenTelemetry semantic conventions:

- `event_domain`: Category (e.g., "user", "system")
- `event_name`: Specific event (e.g., "login", "error")

## Metrics Table

All OpenTelemetry metric types in a unified table.

```sql
CREATE TABLE metrics (
    tenant_id VARCHAR NOT NULL,
    account_id VARCHAR,
    service_name VARCHAR NOT NULL,

    timestamp TIMESTAMP(6) WITH TIME ZONE NOT NULL,
    start_timestamp TIMESTAMP(6) WITH TIME ZONE,
    ingested_timestamp TIMESTAMP(6) WITH TIME ZONE NOT NULL,

    metric_name VARCHAR NOT NULL,
    metric_type VARCHAR NOT NULL,
    description VARCHAR,
    unit VARCHAR,

    aggregation_temporality VARCHAR,
    is_monotonic BOOLEAN,

    attributes MAP(VARCHAR, VARCHAR) NOT NULL,

    -- Gauge/Sum values
    value_double DOUBLE,
    value_int BIGINT,

    -- Histogram values
    count BIGINT,
    sum DOUBLE,
    min DOUBLE,
    max DOUBLE,
    bucket_counts ARRAY(BIGINT),
    explicit_bounds ARRAY(DOUBLE),

    -- Exponential histogram
    scale INTEGER,
    zero_count BIGINT,
    zero_threshold DOUBLE,
    positive_offset INTEGER,
    positive_bucket_counts ARRAY(BIGINT),
    negative_offset INTEGER,
    negative_bucket_counts ARRAY(BIGINT),

    -- Summary
    quantile_values ARRAY(ROW(
        quantile DOUBLE,
        value DOUBLE
    )),

    -- Exemplars
    flags INTEGER,
    exemplars ARRAY(ROW(
        timestamp TIMESTAMP(6) WITH TIME ZONE,
        value_double DOUBLE,
        value_int BIGINT,
        span_id VARBINARY,
        trace_id VARBINARY,
        attributes MAP(VARCHAR, VARCHAR)
    ))
)
```

**Sorting:** `metric_name`, `service_name`, `timestamp DESC`

### Metric Types

| Type | Fields Used |
|------|-------------|
| `gauge` | `value_double` or `value_int` |
| `sum` | `value_double` or `value_int`, `is_monotonic`, `aggregation_temporality` |
| `histogram` | `count`, `sum`, `min`, `max`, `bucket_counts`, `explicit_bounds` |
| `exponential_histogram` | `count`, `sum`, `scale`, `zero_count`, `positive_*`, `negative_*` |
| `summary` | `count`, `sum`, `quantile_values` |

## Query Examples

### Logs Query

```sql
SELECT timestamp, severity_text, body
FROM logs
WHERE tenant_id = 'my-tenant'
  AND service_name = 'api-service'
  AND timestamp >= TIMESTAMP '2025-01-01 00:00:00 UTC'
ORDER BY timestamp DESC
LIMIT 100;
```

### Trace Reconstruction

```sql
SELECT span_id, name, duration_micros
FROM spans
WHERE tenant_id = 'my-tenant'
  AND trace_id = X'5B8EFFF798038103D269B633813FC60C'
ORDER BY timestamp;
```

### Metrics Aggregation

```sql
SELECT
    date_trunc('hour', timestamp) AS hour,
    avg(value_double) AS avg_value
FROM metrics
WHERE tenant_id = 'my-tenant'
  AND metric_name = 'http_request_duration_seconds'
GROUP BY 1
ORDER BY 1;
```

## Next Steps

- Learn about [Architecture](overview.md)
- Explore [Querying](../guides/querying.md)
- See [Deployment](../operations/deployment.md)

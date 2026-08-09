---
title: Data Model
description: Iceberg table schemas behind {{product_name}} - the logs, spans, events, metrics, operations, and prices tables, shared design patterns, and query examples.
---

# Data Model

{{product_name}} stores observability data in five tenant-scoped Apache Iceberg tables - logs, spans, events, metrics, and operations - plus one global reference table, prices.

## Table Overview

| Table | Description | Primary Use Case |
|-------|-------------|------------------|
| `logs` | OpenTelemetry LogRecords | Application logging |
| `spans` | Distributed trace spans | Request tracing |
| `events` | Semantic events | Business events, alerts |
| `metrics` | All metric types | Performance monitoring |
| `operations` | LLM and agent operations | Token usage, cost, prompt and completion capture |
| `prices` | Global LLM rate card (no `tenant_id`) | Reference rates for costing `operations` |

## Common Design Patterns

### Multi-Tenancy

The five tenant-scoped tables use identity partitioning on `tenant_id`. `prices` is reference data shared by every tenant, so it carries no `tenant_id` and is partitioned differently:

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

## Operations Table

LLM and agent operations, following the OpenTelemetry generative-AI semantic conventions.

```sql
CREATE TABLE operations (
    tenant_id VARCHAR NOT NULL,
    conversation_id VARCHAR,

    -- identity
    trace_id VARBINARY NOT NULL,
    span_id VARBINARY NOT NULL,
    parent_span_id VARBINARY,
    service_name VARCHAR,
    scope_name VARCHAR,
    scope_version VARCHAR,

    -- timing
    timestamp TIMESTAMP(6) WITH TIME ZONE NOT NULL,
    end_timestamp TIMESTAMP(6) WITH TIME ZONE NOT NULL,
    duration_micros BIGINT NOT NULL,
    ingested_timestamp TIMESTAMP(6) WITH TIME ZONE NOT NULL,

    operation_name VARCHAR NOT NULL,

    -- provider and model
    provider_name VARCHAR,
    request_model VARCHAR,
    response_model VARCHAR,
    response_id VARCHAR,

    -- sampling parameters
    temperature DOUBLE,
    top_p DOUBLE,
    top_k BIGINT,
    max_tokens BIGINT,
    frequency_penalty DOUBLE,
    presence_penalty DOUBLE,
    seed BIGINT,
    stream BOOLEAN,
    choice_count BIGINT,
    output_type VARCHAR,
    reasoning_effort VARCHAR,

    time_to_first_chunk_ms BIGINT,

    -- token usage
    input_tokens BIGINT,
    output_tokens BIGINT,
    total_tokens BIGINT,
    reasoning_tokens BIGINT,
    cache_creation_input_tokens BIGINT,
    cache_read_input_tokens BIGINT,

    user_id VARCHAR,

    -- tool calls
    tool_name VARCHAR,
    tool_call_id VARCHAR,
    tool_type VARCHAR,
    tool_description VARCHAR,

    data_source_id VARCHAR,
    embedding_dimensions INTEGER,

    -- server and status
    server_address VARCHAR,
    server_port INTEGER,
    status_code INTEGER,
    status_message VARCHAR,
    error_type VARCHAR,

    -- agent and workflow
    agent_id VARCHAR,
    agent_name VARCHAR,
    agent_version VARCHAR,
    agent_description VARCHAR,
    workflow_name VARCHAR,

    -- content, JSON-encoded
    input_messages VARCHAR,
    output_messages VARCHAR,
    system_instructions VARCHAR,
    tool_definitions VARCHAR,
    tool_call_arguments VARCHAR,
    tool_call_result VARCHAR,

    stop_sequences ARRAY(VARCHAR),
    finish_reasons ARRAY(VARCHAR),
    encoding_formats ARRAY(VARCHAR)
)
```

**Partitioning:** `tenant_id` (identity), `day(timestamp)`

**Sorting:** `trace_id`, `timestamp DESC` - clusters a trace's operations together, recent first

The six `VARCHAR` content columns (`input_messages`, `output_messages`, `system_instructions`, `tool_definitions`, `tool_call_arguments`, `tool_call_result`) hold JSON-encoded payloads rather than parsed structures, so prompt and completion shapes can vary per provider without a schema change.

## Prices Table

A global LLM rate card, populated by the Maintain service's pricing crawler from the OpenRouter and LiteLLM feeds.

Unlike the five telemetry tables it carries **no `tenant_id`** - rates are reference data, identical for every tenant. It is an append-only observation log: a row is written only when a rate first differs from the previous one for its key, and `valid_to` is derived at query time.

**Key:** `(provider, model, service_tier, region, min_input_tokens, valid_from)`

Context tiers and service tiers live in the key rather than in extra columns, so the rate columns stay flat as the card grows. Rate columns are `DECIMAL(38, 10)` rather than floating point - money has to be exact, and binary `f64` cannot represent a value like `0.075` or sum it without drift.

### Joining Prices to Operations

The query engine exposes a derived view, `prices_effective`, which adds `valid_to` - the next revision's `valid_from` for the same key, `NULL` for the row currently in effect. It is a DataFusion object, so the Loki, Tempo, and Flight SQL paths see it; Trino reads the Iceberg catalog directly and does not, which is why the raw table stays self-sufficient.

{% note warning %}

{{product_name}} does not compute cost, and `operations` does not carry the full pricing key. It records `provider_name` and `request_model`, which line up with `prices.provider` and `prices.model`, but nothing for `service_tier`, `region`, or `min_input_tokens`. A cost query has to supply those three from deployment knowledge - a fixed tier and region per account, say. Treat such a join as an estimate parameterised by your own assumptions, not a derivation the schema guarantees.

{% endnote %}

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

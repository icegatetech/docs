---
title: Architecture Overview
description: {{product_name}} system architecture and components
---

# Architecture Overview

{{product_name}} is an observability data lake engine that stores logs, traces, metrics, events, and LLM operations in Apache Iceberg tables with DataFusion as the query engine.

## Design Principles

- **Compute-Storage Separation**: Scale processing and storage independently
- **Open Standards**: Built on Apache Iceberg, Arrow, Parquet, and OpenTelemetry
- **Cost-Effective**: Object storage-based architecture minimizes infrastructure costs
- **ACID Transactions**: Full transaction support without a dedicated OLTP database

## System Context

![System Context](../../assets/c4/structurizr-SystemContext.png)

## Container Diagram

![Containers](../../assets/c4/structurizr-Containers.png)

## Component Details

### Ingest Service

![Ingest Components](../../assets/c4/structurizr-IngestComponents.png)

**Purpose:** Accept observability data via OpenTelemetry Protocol (OTLP)

- **Protocols:** OTLP HTTP (port 4318), OTLP gRPC (port 4317)
- **Delivery Guarantee:** Exactly-once delivery
- **Write Path:** Data → WAL (Parquet) → Object Storage

The Write-Ahead Log (WAL) stores data as Parquet files organized for compatibility with the Iceberg storage layer. WAL files can be queried directly for real-time data access.

### Query Service

![Query Components](../../assets/c4/structurizr-QueryComponents.png)

**Purpose:** Execute queries against logs, traces, metrics, and events

- **Engine:** Apache DataFusion + Apache Arrow
- **APIs:** Loki (3100), Tempo (3200), Arrow Flight SQL (8815); Prometheus (9090) serves routes but its handlers still return `501 Not Implemented`
- **Query Languages:** LogQL, TraceQL, SQL; PromQL planned
- **Multi-tenancy:** Tenant taken from the `X-Scope-OrgID` header, or the `x-scope-orgid` gRPC metadata for Flight SQL

Arrow Flight SQL is strictly read-only — DDL and DML are rejected — and enforces `tenant_id` at the row level on every scan, so JDBC, ODBC, and ADBC clients query `iceberg.icegate.<table>` with no {{product_name}}-specific client code.

The query service reads from both:

- **WAL**: For real-time data (seconds-old)
- **Iceberg Tables**: For historical data (shifted and compacted)

The boundary between the two is the WAL offset recorded in the Iceberg snapshot summary, so a row is read from exactly one side and never counted twice.

### Maintain Service

![Maintain Components](../../assets/c4/structurizr-MaintainComponents.png)

**Purpose:** Data lifecycle and optimization operations

- **Schema migration:** Create the Iceberg tables (`maintain migrate create`)
- **Data compaction:** Rewrite small Parquet data files into fewer, larger sorted ones
- **Manifest compaction:** Repack fragmented Iceberg manifests
- **Orphan GC:** Delete objects the current table metadata no longer references, once past a grace period
- **Pricing crawler:** Crawl LLM rate cards from external feeds into the global `icegate.prices` table

Compaction, GC, and the pricing crawler each run as jobs whose state lives in object storage, under their own job-state prefix.

### Catalog

![Catalog Components](../../assets/c4/structurizr-CatalogComponents.png)

**Purpose:** Organize the data lake with ACID transactions, without a dedicated OLTP database

- **Default backend:** {{product_name}}'s own S3 catalog — catalog state is a `root.json` object updated by compare-and-swap
- **Alternative backends:** REST (Nessie), AWS S3 Tables, AWS Glue
- **Deployment:** Linked into Ingest, Query, and Maintain by default; optionally deployed standalone as an Iceberg REST server on port 8181

A conditional read keeps the cached catalog root fresh; table metadata is immutable per location, so it is cached unconditionally in an LRU.

### Alert Service (Planned)

**Purpose:** Rule-based alerting on observability data

- Rule management for defining alert conditions
- Real-time analysis using the Query service
- Event generation following OpenTelemetry semantic conventions

## Technology Stack

| Component | Technology | Purpose |
|-----------|------------|---------|
| Table Format | Apache Iceberg 0.9 | ACID transactions, time travel, schema evolution |
| Query Engine | Apache DataFusion 52.2 | Vectorized query execution |
| Memory Format | Apache Arrow 57.0 | Zero-copy data processing |
| Storage Format | Apache Parquet 57.0 | Columnar storage with ZSTD compression |
| Ingestion | OpenTelemetry 0.31 | Standard observability protocol (gRPC + HTTP) |
| SQL Interface | Arrow Flight SQL 57.0 | Read-only SQL for JDBC, ODBC, and ADBC clients |
| Catalog | S3 catalog (default), Nessie, AWS S3 Tables, AWS Glue | Iceberg catalog backends; the default keeps state in object storage |
| Object Storage | RustFS, or any S3-compatible store | WAL segments, Iceberg data, catalog state, job state |
| Job Manager | jobmanager (separate repository) | S3-based job state for shift, compaction, GC, and pricing |
| Caching | foyer 0.22 | Hybrid memory + disk cache for S3 reads |
| Language | Rust {{rust_version}}+ (2024 edition) | Memory-safe, high-performance runtime |

## Data Flow

### Ingestion Flow

![Ingestion Sequence](../../assets/c4/structurizr-IngestionFlow.png)

Steps 1-7 are the write path, acknowledged once the WAL segment lands. Steps 8-14 are shift, which runs independently of the request.

1. Client sends OTLP data to Ingest service
2. Ingest validates and transforms data
3. Data written to WAL as Parquet files
4. Acknowledgment sent to client (exactly-once)

### Query Flow

![Query Sequence](../../assets/c4/structurizr-QueryFlow.png)

1. Client sends query to Query service
2. Query parsed and planned by DataFusion
3. Data read from Iceberg tables and/or WAL
4. Results formatted and returned

### Shift (Compaction) Flow

1. Ingest service's shift process monitors WAL segments
2. Groups segments into shift tasks
3. Reads WAL files in parallel, merges and re-partitions data
4. Writes optimized Iceberg data files
5. Commits a new snapshot to the catalog, recording the last committed WAL offset in the snapshot summary

Shift never deletes WAL segments. They are reclaimed by an object lifecycle rule on the queue bucket, and the offset in the snapshot summary is what lets shift resume where it left off.

That makes the lifecycle expiration a durability parameter, not housekeeping: a segment has to outlive the commit that covers it. If shift is delayed or failing when the rule fires, segments whose offsets were never committed are deleted and the data is gone. See [Data Retention](../guides/data-retention.md) for sizing.

### Maintenance Flow

![Maintenance Sequence](../../assets/c4/structurizr-MaintenanceFlow.png)

Migration is a one-shot job. Compaction, orphan GC, and the pricing crawler are independent loops on their own schedules — the step numbers order each loop, not the loops against each other. Each claims work under its own job-state prefix, so the loops never fight over task ownership. They still share the tables underneath — compaction commits rewrite snapshots while GC deletes unreferenced objects — which is why GC only removes files older than its grace period and commits use optimistic concurrency, retrying on conflict.

## Scalability

### Horizontal Scaling

- **Ingest:** Scale replicas for higher throughput
- **Query:** Scale replicas for concurrent queries
- **Maintain:** Scale replicas for more rewrite throughput — workers share job state in object storage with compare-and-swap and commit with optimistic concurrency, so parallel instances are safe. Prefer raising in-process worker count first; returns taper as replicas grow, since all workers on a table contend on one job-state object.

### Storage Scaling

- Object storage scales independently
- No capacity limits (pay-per-use)
- Cross-region replication supported

## Next Steps

- Learn about the [Data Model](data-model.md)
- Explore [Deployment](../operations/deployment.md) options
- See [Configuration](../getting-started/configuration.md) details

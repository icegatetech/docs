---
title: FAQ
description: Frequently asked questions about {{product_name}}
---

# Frequently Asked Questions

## General

### What is {{product_name}}?

{{product_name}} is an observability data lake engine that stores logs, traces, metrics, and events in Apache Iceberg tables. It provides Loki- and Tempo-compatible APIs for querying, plus Arrow Flight SQL. A Prometheus-compatible API is [planned but not implemented yet](api-reference/prometheus.md) — see the [Loki](api-reference/loki.md) and [Tempo](api-reference/tempo.md) references for what is served today.

### What makes {{product_name}} different?

- **Open Standards**: Built entirely on Apache Iceberg, Arrow, Parquet, and OpenTelemetry
- **Cost-Effective**: Uses object storage (S3 or RustFS) instead of expensive databases
- **ACID Transactions**: Full transaction support without a dedicated OLTP database
- **Compute-Storage Separation**: Scale processing and storage independently

### What is the current status?

{{product_name}} is in **alpha** development. Core features work, but APIs may change.

### What license is {{product_name}} under?

{{license}}.

## Getting Started

### What are the minimum requirements?

- Rust {{rust_version}}+
- Docker (for development environment)
- S3-compatible object storage

### How do I get started?

See the [Installation](getting-started/installation.md) guide and [Quick Start](getting-started/quickstart.md).

### Do I need Kubernetes?

No. {{product_name}} can run with Docker Compose for smaller deployments. Kubernetes is recommended for production.

## Data and Storage

### Where is data stored?

All data is stored in S3-compatible object storage:

- WAL (Write-Ahead Log) for recent data
- Iceberg tables for historical data
- Catalog metadata in Nessie

### What data formats are used?

- **Storage**: Apache Parquet with ZSTD compression
- **In-memory**: Apache Arrow
- **Table Format**: Apache Iceberg v2

### How is data organized?

Data is partitioned by:

1. `tenant_id` - Multi-tenancy isolation
2. `account_id` - Optional sub-tenant partitioning
3. `day(timestamp)` - Time-based partitioning

### What is the data retention?

Configurable per table. Default: 30 days for logs, 14 days for traces.

## Querying

### What query languages are supported?

- **LogQL**: For querying logs (Grafana Loki compatible)
- **PromQL**: Planned for metrics
- **TraceQL**: Planned for traces

### What LogQL features are implemented?

See [Querying Guide](guides/querying.md) for the full feature matrix.

Implemented:

- Log stream selectors
- Line filters (contains, regex)
- Range aggregations (count_over_time, rate, bytes_rate)
- Vector aggregations (sum, avg, min, max)

Not yet implemented:

- Pipeline parsers (json, logfmt)
- Unwrap aggregations
- Binary operations

### Can I use Grafana?

Yes. {{product_name}} provides Loki-compatible APIs that work with Grafana's Loki data source, and Tempo-compatible APIs for the Tempo data source. Both implement a subset of the upstream API, so check the [Loki](api-reference/loki.md) and [Tempo](api-reference/tempo.md) references if a panel depends on a specific endpoint. The Prometheus data source will not work yet — that API is planned.

## Multi-Tenancy

### How does multi-tenancy work?

Tenants are identified by the `X-Scope-OrgID` HTTP header. All data is partitioned by tenant_id.

### Is tenant data isolated?

Yes. Queries only access data for the tenant specified in the header. Data is physically partitioned.

### Can I have multiple tenants in one deployment?

Yes. {{product_name}} is designed as a multi-tenant system.

## Performance

### How does {{product_name}} scale?

- **Ingest**: Horizontal scaling for write throughput
- **Query**: Horizontal scaling for concurrent queries
- **Storage**: Object storage scales independently

### What query performance can I expect?

Performance depends on:

- Time range of query
- Partition pruning (filter on tenant_id, timestamp)
- Query complexity

Typical sub-second response for filtered queries over recent data.

### How is data compacted?

The Ingest service's built-in shift process automatically compacts WAL files into optimized Iceberg tables with larger file sizes and better statistics.

## Operations

### How do I monitor {{product_name}}?

- Prometheus metrics exposed on each service
- Health check endpoints
- Query explain endpoint for debugging

### What about high availability?

- Ingest and Query services can run multiple replicas
- Object storage provides durability
- Nessie catalog stores metadata

### How do I backup data?

- Enable S3 versioning for point-in-time recovery
- Iceberg supports time-travel queries
- Export Nessie catalog metadata

## Integration

### What ingestion protocols are supported?

OpenTelemetry Protocol (OTLP):

- HTTP (port 4318)
- gRPC (port 4317)

### Can I use existing OTEL collectors?

Yes. Any OpenTelemetry-compatible collector can send data to IceGate.

### What about Prometheus remote write?

Planned for future releases.

## Troubleshooting

### My queries return empty results

1. Check tenant ID is correct
2. Verify time range includes your data
3. Wait for data compaction or query WAL directly

### Data is not appearing after ingestion

1. Verify 200 OK response from ingest endpoint
2. Check WAL files in object storage
3. Check Ingest service logs

### Query timeout

1. Add time range filters
2. Filter on partition columns (tenant_id)
3. Reduce result limit

See [Troubleshooting](operations/troubleshooting.md) for more.

## Contributing

### How can I contribute?

See [Contributing Guide](development/contributing.md). We welcome:

- Bug reports
- Feature requests
- Pull requests
- Documentation improvements

### Where do I report issues?

GitHub Issues: [{{repo_url}}/issues]({{repo_url}}/issues)

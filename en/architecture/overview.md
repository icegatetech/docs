---
title: Architecture Overview
description: IceGate system architecture and components
---

# Architecture Overview

IceGate is an observability data lake engine that stores logs, traces, metrics, and events in Apache Iceberg tables with DataFusion as the query engine.

## Design Principles

- **Compute-Storage Separation**: Scale processing and storage independently
- **Open Standards**: Built on Apache Iceberg, Arrow, Parquet, and OpenTelemetry
- **Cost-Effective**: Object storage-based architecture minimizes infrastructure costs
- **ACID Transactions**: Full transaction support without a dedicated OLTP database

## System Components

```
┌─────────────────────────────────────────────────────────────────┐
│                         Clients                                  │
│   (OpenTelemetry SDK, Grafana, curl, Applications)              │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                      IceGate Services                            │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────┐│
│  │   Ingest    │  │    Query    │  │  Maintain   │  │  Alert  ││
│  │  (OTLP)     │  │ (Loki/Prom) │  │ (Compaction)│  │ (Rules) ││
│  └─────────────┘  └─────────────┘  └─────────────┘  └─────────┘│
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                     Catalog (Nessie)                             │
│              Apache Iceberg REST Catalog                         │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                  Object Storage (S3/MinIO)                       │
│    ┌─────────┐    ┌─────────────┐    ┌──────────────┐          │
│    │   WAL   │    │   Iceberg   │    │   Catalog    │          │
│    │ (Live)  │    │   Tables    │    │   Metadata   │          │
│    └─────────┘    └─────────────┘    └──────────────┘          │
└─────────────────────────────────────────────────────────────────┘
```

## Component Details

### Ingest Service

**Purpose:** Accept observability data via OpenTelemetry Protocol (OTLP)

- **Protocols:** OTLP HTTP (port 4318), OTLP gRPC (port 4317)
- **Delivery Guarantee:** Exactly-once delivery
- **Write Path:** Data → WAL (Parquet) → Object Storage

The Write-Ahead Log (WAL) stores data as Parquet files organized for compatibility with the Iceberg storage layer. WAL files can be queried directly for real-time data access.

### Query Service

**Purpose:** Execute queries against logs, traces, metrics, and events

- **Engine:** Apache DataFusion + Apache Arrow
- **APIs:** Loki (3100), Prometheus (9090), Tempo (3200)
- **Query Languages:** LogQL, PromQL (planned), TraceQL (planned)

The query service reads from both:

- **WAL**: For real-time data (seconds-old)
- **Iceberg Tables**: For historical data (compacted)

### Maintain Service

**Purpose:** Data lifecycle and optimization operations

- **Compaction:** Merge small WAL files into optimized Iceberg tables
- **TTL:** Expire and delete old data based on retention policies
- **Optimization:** Rewrite data files for better query performance
- **Cleanup:** Remove orphaned files and expired snapshots

### Alert Service (Planned)

**Purpose:** Rule-based alerting on observability data

- Rule management for defining alert conditions
- Real-time analysis using the Query service
- Event generation following OpenTelemetry semantic conventions

## Technology Stack

| Component | Technology | Purpose |
|-----------|------------|---------|
| Table Format | Apache Iceberg | ACID transactions, time travel, schema evolution |
| Query Engine | Apache DataFusion | Vectorized query execution |
| Memory Format | Apache Arrow | Zero-copy data processing |
| Storage Format | Apache Parquet | Columnar storage with compression |
| Ingestion | OpenTelemetry | Standard observability protocol |
| Catalog | Nessie | Iceberg REST catalog with Git-like semantics |

## Data Flow

### Ingestion Flow

1. Client sends OTLP data to Ingest service
2. Ingest validates and transforms data
3. Data written to WAL as Parquet files
4. Acknowledgment sent to client (exactly-once)

### Query Flow

1. Client sends query to Query service
2. Query parsed and planned by DataFusion
3. Data read from Iceberg tables and/or WAL
4. Results formatted and returned

### Compaction Flow

1. Maintain service monitors WAL size
2. When threshold reached, reads WAL files
3. Merges and optimizes data
4. Writes new Iceberg data files
5. Commits new snapshot to catalog
6. Deletes processed WAL files

## Scalability

### Horizontal Scaling

- **Ingest:** Scale replicas for higher throughput
- **Query:** Scale replicas for concurrent queries
- **Maintain:** Single instance (leader election)

### Storage Scaling

- Object storage scales independently
- No capacity limits (pay-per-use)
- Cross-region replication supported

## Next Steps

- Learn about the [Data Model](data-model.md)
- Explore [Deployment](../operations/deployment.md) options
- See [Configuration](../getting-started/configuration.md) details

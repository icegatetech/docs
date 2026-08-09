# IceGate C4 Architecture

C4 model architecture diagrams for IceGate using [Structurizr DSL](https://structurizr.com/dsl).

## Technology

- **[Structurizr DSL](https://docs.structurizr.com/dsl/language)** - Architecture as code
- **[C4 Model](https://c4model.com/)** - Software architecture visualization
- **[structurizr-cli](https://github.com/structurizr/cli)** - Command-line export tool

## Prerequisites

```bash
# Install structurizr-cli and plantuml (macOS)
brew install structurizr-cli plantuml

# Or use Docker for Structurizr Lite
docker pull structurizr/lite
```

## Usage

```bash
# Generate PNG diagrams
make png

# Generate SVG diagrams
make svg

# Validate workspace syntax
make validate

# Run interactive UI (requires Docker)
make lite

# Show all commands
make help
```

## Generated Diagrams

After running `make png`, the following files are created in `../assets/c4/`:

| File | Description |
|------|-------------|
| `structurizr-SystemContext.png` | System context - IceGate and external systems |
| `structurizr-Containers.png` | Container diagram - Services, libraries and storage |
| `structurizr-IngestComponents.png` | Ingest Service internal components |
| `structurizr-QueryComponents.png` | Query Service internal components |
| `structurizr-QueueComponents.png` | Queue Library internal components |
| `structurizr-MaintainComponents.png` | Maintain Service internal components |
| `structurizr-CatalogComponents.png` | S3 Catalog internal components |
| `structurizr-IngestionFlow.png` | Ingestion process (sequence) - OTLP request through shift to a committed snapshot |
| `structurizr-QueryFlow.png` | Query process (sequence) - LogQL request to a merged WAL and Iceberg result |
| `structurizr-MaintenanceFlow.png` | Maintenance process (sequence) - migration, compaction, orphan GC, pricing crawler |

## Workspace Structure

```
workspace.dsl
├── Model
│   ├── External Systems (OTel Collector/SDK, Grafana, BI & SQL clients,
│   │                     Prometheus, tracing backend, Trino, LLM pricing feeds)
│   └── IceGate System
│       ├── Ingest Service (OTLP handlers, transform, WAL writer, shift)
│       ├── Query Service (Loki/Prometheus/Tempo/Flight SQL, LogQL, TraceQL)
│       ├── Maintain Service (migrate, compaction, orphan GC, pricing crawler)
│       ├── S3 Catalog (root.json CAS catalog; optional REST server)
│       ├── Queue Library (Parquet WAL on S3)
│       ├── Common Library (schemas, storage cache, sort-merge, memory guard)
│       └── Storage (Queue/WAL, Iceberg, Catalog, Job state)
└── Views
    ├── SystemContext
    ├── Containers
    ├── Component diagrams (Ingest, Query, Maintain, Queue, Catalog)
    └── Process diagrams (Ingestion, Query, Maintenance)
```

## Process Diagrams

The three `*Flow` views are Structurizr [dynamic views](https://docs.structurizr.com/dsl/language#dynamic-view).
Two things to know before editing them:

- **Every step must correspond to a relationship that already exists in the model.** A dynamic
  view may give that relationship a step-specific description, but it cannot invent an edge —
  the DSL fails with `A relationship between X and Y does not exist in model`. When a flow needs
  a step you have not modelled, add the relationship to the `model` block first.
- **They render as UML sequence diagrams**, via the per-view
  `properties { "plantuml.sequenceDiagram" "true" }`. Without it the exporter falls back to the
  numbered box layout, which turns into unreadable long-arc spaghetti past about ten steps.
  `autoLayout` is kept on each view as the fallback for that case.

Structurizr's parallel-block syntax (`{ { … } { … } }`) is deliberately unused: both PlantUML
exporters flatten it into duplicate step numbers with no visual grouping, so concurrent loops
read as one pipeline. The maintenance view names the owning loop in each step description
instead.

## Interactive Editing

For the best editing experience, use Structurizr Lite:

```bash
make lite
# Open http://localhost:8080
```

This provides:
- Live diagram preview
- Syntax highlighting
- Drag-and-drop layout adjustments
- Export to multiple formats

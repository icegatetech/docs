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
| `structurizr-Containers.png` | Container diagram - Services and storage |
| `structurizr-IngestComponents.png` | Ingest Service internal components |
| `structurizr-QueryComponents.png` | Query Service internal components |
| `structurizr-QueueComponents.png` | Queue Library internal components |
| `structurizr-MaintainComponents.png` | Maintain Service internal components |

## Workspace Structure

```
workspace.dsl
├── Model
│   ├── External Systems (OTel Collector, Grafana, Trino)
│   └── IceGate System
│       ├── Ingest Service (OTLP handlers, compactor)
│       ├── Query Service (Loki/Prometheus/Tempo APIs)
│       ├── Maintain Service (schema migrations)
│       ├── Queue Library (WAL on S3)
│       ├── Common Library (shared code)
│       └── Storage (Queue, Iceberg, Catalog)
└── Views
    ├── SystemContext
    ├── Containers
    └── Component diagrams (per service)
```

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

# AGENTS.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

IceGate documentation site built with [Diplodoc](https://diplodoc.com/) (YFM - Yandex Flavored Markdown). Multi-language documentation (en, fr, ru) for an Observability Data Lake engine.

Source code repository: https://github.com/icegatetech/icegate

## Commands

```bash
npm run build      # Build all languages to ./build (includes llms.txt files)
npm run lint       # Lint docs with --strict mode
npm run serve      # Build and serve locally on port 8080
npm run clean      # Remove build directory
```

Language-specific builds:
```bash
npm run build:en   # Build English only
npm run build:fr   # Build French only
npm run build:ru   # Build Russian only
```

**Do not drop `--static-content` from the build scripts.** Its help text ("allow loading custom
resources into statically generated pages") undersells it: without the flag Diplodoc ships every
page as an empty `<div id="root">` with the real content parked in a `diplodoc-state` JSON blob,
so a crawler that does not run JavaScript sees ~4 words, no `<h1>`, and — because the TOC is
rendered client-side too — no links to follow. Ahrefs found 4 of this site's pages for exactly
that reason. With the flag, pages ship prerendered (~670 words and a real `<h1>` on a typical
page) and the client bundle still hydrates on top, so nothing about the reading experience
changes. Removing it breaks search and AI-crawler visibility site-wide, silently and with a
green build.

## Project Structure

```
├── en/                    # English documentation (primary)
├── fr/                    # French documentation
├── ru/                    # Russian documentation
├── llms.txt               # LLM context file — overview with key examples
├── llms-full.txt          # LLM context file — complete documentation content
├── presets.yaml           # Build presets (default, development, production)
├── .yfm                   # Diplodoc configuration (vars, langs, settings)
└── .yfmlint               # Linter rules configuration
```

Each language directory has identical structure:
- `index.yaml` - Landing page configuration
- `toc.yaml` - Table of contents and navigation

### Documentation Sections

| Section | Path | Description |
|---------|------|-------------|
| **Installation** | `getting-started/installation.md` | Helm chart, Kustomize overlays (production) |
| **Quick Start** | `getting-started/quickstart.md` | Ingest data, query with LogQL, use Grafana |
| **Configuration** | `getting-started/configuration.md` | Full parameter reference for all services |
| **Guides** | `guides/` | Ingestion, querying, multi-tenancy |
| **API Reference** | `api-reference/` | OTLP, Loki, Prometheus, Tempo APIs |
| **Architecture** | `architecture/` | System overview, data model |
| **Operations** | `operations/` | Deployment, maintenance, troubleshooting |
| **Development** | `development/` | Dev setup (Skaffold), building, patterns, contributing |
| **FAQ** | `faq.md` | Frequently asked questions |

## LLM Context Files

- **`llms.txt`** — Concise overview: installation, config syntax, usage examples, architecture summary. Optimized for quick LLM context loading.
- **`llms-full.txt`** — Complete English documentation concatenated. Order prioritizes production use: Installation → Configuration → Quick Start → Guides → API → Architecture → Operations → Development → FAQ.

Both files are copied to `./build/` during the build step and served at the doc site root (`/llms.txt`, `/llms-full.txt`).

When updating documentation, regenerate `llms-full.txt` after changes. `llms.txt` is manually maintained and should be updated when key features, config syntax, or APIs change.

## Configuration Files

- **`.yfm`** - Main config: variables (`{{product_name}}`), language settings, markdown options
- **`presets.yaml`** - Variable presets for different build environments
- **`.yfmlint`** - Markdown/YFM linting rules (MD* for markdownlint, YFM* for Diplodoc)

## Writing Documentation

- Use variables from `.yfm` vars section: `{{product_name}}`, `{{version}}`, `{{repo_url}}`
- HTML is allowed (`allowHTML: true`)
- Files must end with newline (MD047 enforced)
- Line length not enforced (MD013 disabled)
- Config YAML examples must use serde tagged enum syntax: `backend: !rest`, `backend: !s3`, `backend: !s3tables`, `backend: !glue`, `backend: !memory`, `backend: !filesystem`
- Translate code-block comments to the target language in FR/RU docs
- Keep parameter names, CLI commands, and code syntax in English across all language translations

## Key Technical Details

- IceGate config uses **YAML tagged enums** (serde): `backend: !rest`, `backend: !s3`, `backend: !s3tables`, `backend: !glue`, `backend: !memory`, `backend: !filesystem`
- Primary installation method: **Helm chart** (`oci://ghcr.io/icegatetech/charts/icegate`)
- Development environment: **Skaffold** (`skaffold dev`) with Kustomize overlays
- Docker Compose available as alternative for local development
- Rust 1.92.0+ (2024 edition), 6 workspace crates: common, queue, query, ingest, maintain, jobmanager
- Metrics port: **9091** (not 9090). Prometheus API port is 9090.
- Real environment variables: `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `OTEL_EXPORTER_OTLP_ENDPOINT`, `RUST_LOG`

## Deployment

GitHub Pages deployment via Actions (`.github/workflows/deploy-pages.yml`) triggers on push to `main`.
PR lint checks run via `.github/workflows/lint.yml`.

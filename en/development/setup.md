---
title: Development Setup
description: Set up a local {{product_name}} development environment
---

# Development Setup

This guide covers setting up a local {{product_name}} development environment for contributing code, running tests, and debugging.

## Prerequisites

- **Rust** >= {{rust_version}} (Rust 2024 edition)
- **Docker** (for building container images)
- **Git**
- A local Kubernetes cluster (for Skaffold)

### Install Rust

```bash
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
source $HOME/.cargo/env
rustc --version  # Should be >= 1.92.0
```

### Clone the Repository

```bash
git clone https://github.com/icegatetech/icegate.git
cd icegate
```

## Skaffold (Recommended)

[Skaffold](https://skaffold.dev/) is the recommended way to develop IceGate. It builds images from source, deploys to a local Kubernetes cluster, and watches for file changes to automatically rebuild.

### Install Skaffold

```bash
# macOS
brew install skaffold

# Linux
curl -Lo skaffold https://storage.googleapis.com/skaffold/releases/latest/skaffold-linux-amd64
chmod +x skaffold && sudo mv skaffold /usr/local/bin/
```

### Local Kubernetes Cluster

You need a local Kubernetes cluster. Options:

| Runtime | Install | Notes |
|---------|---------|-------|
| [OrbStack](https://orbstack.dev/) | macOS only | Lightweight, fast startup. Use `-p orbstack` profile |
| [Docker Desktop](https://docs.docker.com/desktop/kubernetes/) | macOS, Windows, Linux | Enable Kubernetes in settings |
| [minikube](https://minikube.sigs.k8s.io/) | All platforms | `minikube start` |
| [kind](https://kind.sigs.k8s.io/) | All platforms | `kind create cluster` |

### Run with Skaffold

```bash
# Default profile (local k8s with RustFS + the built-in S3 catalog)
skaffold dev

# OrbStack profile
skaffold dev -p orbstack

# AWS Glue profile (pushes images to registry)
skaffold dev -p aws-glue

# External S3 profile
skaffold dev -p k3s-external-s3
```

### What Skaffold Deploys

Skaffold uses Kustomize overlays that compose multiple Helm charts:

**{{product_name}} namespace (`icegate`):**

| Component | Description |
|-----------|-------------|
| `icegate-ingest` | OTLP receivers (gRPC 4317, HTTP 4318) + shift process |
| `icegate-query` | Query APIs (Loki 3100, Prometheus 9090, Tempo 3200) |
| `icegate-migrate` | Schema creation job (Helm pre-install hook) |

**Infrastructure namespace (`infra`):**

| Component | Description |
|-----------|-------------|
| RustFS | S3-compatible storage with buckets: `warehouse`, `queue`, `jobs` |

**Observability namespace (`observability`):**

| Component | Description |
|-----------|-------------|
| Prometheus | Metrics collection (kube-prometheus-stack) |
| Grafana | Dashboards with pre-built {{product_name}} Ingest and Query panels |
| Jaeger | Distributed tracing for {{product_name}} services |

### Skaffold Profiles

| Profile | Overlay | Use Case |
|---------|---------|----------|
| (default) | `skaffold` | Local development with RustFS + the built-in S3 catalog |
| `orbstack` | `orbstack` | OrbStack Kubernetes (macOS) |
| `aws-glue` | `aws-glue` | AWS Glue catalog (pushes images) |
| `k3s-external-s3` | `external-s3` | External S3 + Nessie (pushes images) |

### Accessing Services

```bash
# Port-forward IceGate services
kubectl port-forward -n icegate svc/icegate-query 3100:3100 &
kubectl port-forward -n icegate svc/icegate-ingest 4318:4318 4317:4317 &

# Port-forward observability
kubectl port-forward -n observability svc/grafana 3000:80 &
kubectl port-forward -n observability svc/jaeger-query 16686:16686 &
```

### Modifying Code

Skaffold watches the `crates/` directory and automatically rebuilds images when files change. The rebuild-deploy cycle takes about 1-2 minutes for a release build.

To iterate faster on a specific service without rebuilding images, you can `cargo build` locally and run the binary directly with a config file (see [Building from Source](building.md)).

## Docker Compose (Alternative)

Docker Compose is available as a simpler alternative that doesn't require Kubernetes.

### Start Development Stack

```bash
# Core services with hot-reload (debug build)
make dev

# Core services in release mode
make run-core-release

# With load generator
make run-load-release

# With monitoring (Jaeger, Prometheus)
make run-monitoring-release

# With analytics (Trino SQL)
make run-analytics-release

# Stop all services
make down
```

### Docker Compose Services

| Service | Port | Description |
|---------|------|-------------|
| RustFS | 9000, 9001 | S3-compatible storage + console |
| Ingest | 4317, 4318 | OTLP gRPC and HTTP receivers |
| Query | 3100, 9090, 3200, 8815 | Loki, Tempo, Arrow Flight SQL APIs; Prometheus routes return 501 except `/-/ready` |
| Grafana | 3000 | Dashboards |

Docker Compose profiles add optional services:

| Profile | Services |
|---------|----------|
| `load` | otelgen (log load generator) |
| `monitoring` | Jaeger (16686), Prometheus (9092), node-exporter, cAdvisor |
| `analytics` | Nessie (19120) and Trino SQL engine (8082) |

### Docker Build

Build individual container images:

```bash
# Using the release Dockerfile (multi-arch, cargo-chef cached)
docker build -t icegate/query:latest \
  --build-arg BINARY=query \
  -f config/docker/release.Dockerfile .

# Using the dev Dockerfile (simpler, single-arch)
docker build -t icegate/query:dev \
  --build-arg BINARY=query \
  --build-arg PROFILE=debug \
  -f config/docker/Dockerfile .
```

## Environment Variables

For local development with RustFS:

```bash
export AWS_ACCESS_KEY_ID=rustfsadmin
export AWS_SECRET_ACCESS_KEY=rustfsadmin
export AWS_REGION=us-east-1
```

## Next Steps

- Learn how to [Build from Source](building.md) and run individual services
- Read [Development Patterns](patterns.md) for coding conventions
- See [Contributing](contributing.md) for PR guidelines

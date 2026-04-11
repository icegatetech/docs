---
title: Building from Source
description: Build IceGate from source code
---

# Building from Source

This guide covers building IceGate from source for development and production.

## Prerequisites

### Required

- **Rust** >= 1.92.0 (for Rust 2024 edition support)
- **Cargo** (included with Rust)
- **Git**

### Optional

- **Java** (for regenerating ANTLR parser)
- **Docker** (for development environment)
- **protoc** (for regenerating protobuf code)

## Install Rust

```bash
# Install via rustup
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh

# Verify installation
rustc --version
cargo --version
```

## Clone Repository

```bash
git clone https://github.com/icegatetech/icegate.git
cd icegate
```

## Build

### Debug Build

```bash
cargo build
```

Build artifacts in `target/debug/`.

### Release Build

```bash
cargo build --release
```

Build artifacts in `target/release/`.

### Specific Binaries

```bash
# Query service only
cargo build --bin query

# Ingest service only
cargo build --bin ingest

# Maintain service only
cargo build --bin maintain
```

## Build Profiles

| Profile | Command | Use Case |
|---------|---------|----------|
| dev | `cargo build` | Development, debugging |
| release | `cargo build --release` | Production |
| test | `cargo test` | Running tests |
| bench | `cargo bench` | Benchmarks |

### Profile Configuration

Custom profiles are in `Cargo.toml`:

```toml
[profile.release]
opt-level = 3
lto = true
codegen-units = 1

[profile.dev]
opt-level = 0
debug = true
```

## Workspace Structure

IceGate uses a Cargo workspace:

```text
Cargo.toml (workspace)
├── crates/
│   ├── icegate-common/Cargo.toml
│   ├── icegate-queue/Cargo.toml
│   ├── icegate-query/Cargo.toml
│   ├── icegate-ingest/Cargo.toml
│   ├── icegate-maintain/Cargo.toml
│   └── icegate-jobmanager/Cargo.toml
```

Build individual crates:

```bash
cargo build -p icegate-query
cargo build -p icegate-common
```

## Running Services

### Query Service

```bash
cargo run --bin query -- run -c config/docker/query.yaml
```

### Ingest Service

```bash
cargo run --bin ingest -- run -c config/docker/ingest.yaml
```

### Maintain Service

```bash
cargo run --bin maintain -- migrate create -c config/docker/maintain.yaml
```

## LogQL Parser Regeneration

The LogQL parser is generated from ANTLR4 grammar files.

### Prerequisites

- Java JDK 11+

### Generate Parser

```bash
cd crates/icegate-query/src/logql

# Install ANTLR jar (first time)
make install

# Regenerate parser from .g4 files
make gen
```

Grammar files are in `crates/icegate-query/src/logql/antlr/`.

## Running Tests

```bash
# All tests
cargo test

# Specific test
cargo test test_name

# With output shown
cargo test -- --nocapture

# Release mode (faster but longer build)
cargo test --release
```

## Code Quality

```bash
# Format check
make fmt

# Linting
make clippy

# Security audit
make audit

# All CI checks
make ci
```

## Build Troubleshooting

### Compilation Errors

1. Ensure Rust version >= 1.92.0:

   ```bash
   rustup update
   ```

2. Clean build artifacts:

   ```bash
   cargo clean
   cargo build
   ```

### Linking Errors

Some dependencies require system libraries:

**macOS:**

```bash
brew install openssl
```

**Ubuntu/Debian:**

```bash
apt install libssl-dev pkg-config
```

### Out of Memory

Large codebases may require more memory:

```bash
# Reduce parallelism
cargo build -j 2
```

## Docker Build

Build container images:

```bash
# Release build (multi-arch, cargo-chef cached)
docker build -t icegate/query:latest \
  --build-arg BINARY=query \
  -f config/docker/release.Dockerfile .

# Dev build (simpler, single-arch)
docker build -t icegate/query:dev \
  --build-arg BINARY=query \
  --build-arg PROFILE=debug \
  -f config/docker/Dockerfile .
```

## Next Steps

- Set up a [Development Environment](setup.md) with Skaffold or Docker Compose
- Review [Development Patterns](patterns.md)
- Start [Contributing](contributing.md)

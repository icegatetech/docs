---
title: Installation
description: Install IceGate and its dependencies
---

# Installation

This guide covers installing IceGate and its dependencies for local development and production deployments.

## Prerequisites

### Required Tools

- **Rust** >= 1.92.0 (for Rust 2024 edition support)
- **Cargo** (included with Rust)
- **Git**
- **Docker** and **Docker Compose** (for development environment)

### Optional Tools

- **rustfmt** - for code formatting (included with Rust)
- **clippy** - for linting and static analysis (included with Rust)
- **rust-analyzer** - for IDE support

## Validating Prerequisites

Check if Rust is installed with the correct version:

```bash
# Check Rust version
rustc --version

# Check Cargo version
cargo --version

# Check rustfmt (optional)
rustfmt --version

# Check clippy (optional)
cargo clippy --version
```

You should have Rust 1.92.0 or later installed.

## Installing Rust

If you don't have Rust installed, use rustup (the recommended Rust toolchain installer):

```bash
# Install Rust via rustup
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh

# Follow the prompts to complete installation
# Then reload your shell or run:
source $HOME/.cargo/env

# Verify installation
rustc --version
cargo --version
```

## Installing IceGate

### From Source

Clone the repository and build:

```bash
# Clone the repository
git clone https://github.com/icegatetech/icegate.git
cd icegate

# Build in debug mode
cargo build

# Or build in release mode (optimized)
cargo build --release
```

Build artifacts will be located in:

- Debug: `target/debug/`
- Release: `target/release/`

### Docker

The recommended way to run IceGate for development is using Docker Compose:

```bash
# Start the full development stack
make dev
```

This starts all required services including MinIO (S3), Nessie (Iceberg catalog), Grafana, and the IceGate query service.

## Next Steps

- Continue to [Quick Start](quickstart.md) to ingest your first data
- See [Configuration](configuration.md) for configuration options

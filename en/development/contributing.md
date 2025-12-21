---
title: Contributing
description: How to contribute to IceGate development
---

# Contributing

We welcome contributions to IceGate! This guide explains how to get started.

## Ways to Contribute

- **Report bugs** via GitHub Issues
- **Request features** via GitHub Issues
- **Submit pull requests** for bug fixes or features
- **Improve documentation**
- **Share feedback** and use cases

## Development Setup

### Prerequisites

- Rust >= 1.92.0
- Docker and Docker Compose
- Git

### Clone and Build

```bash
# Clone the repository
git clone https://github.com/icegatetech/icegate.git
cd icegate

# Build the project
cargo build

# Run tests
cargo test
```

### Start Development Environment

```bash
# Start all services with hot-reload
make dev

# Or start without query service for debugging
make debug
```

## Code Style

### Formatting

Use rustfmt with the project configuration:

```bash
# Check formatting
make fmt

# Auto-fix formatting
make fmt-fix
```

Configuration is in `rustfmt.toml`.

### Linting

Use clippy with strict settings:

```bash
# Run clippy
make clippy

# Auto-fix issues
make clippy-fix
```

Configuration is in `clippy.toml`.

### CI Checks

Before submitting, run all CI checks:

```bash
make ci
```

This runs:

1. `cargo check` - compilation check
2. `cargo fmt -- --check` - formatting check
3. `cargo clippy -- -D warnings` - linting
4. `cargo test` - tests
5. `cargo audit` - security audit

## Project Structure

```
crates/
├── icegate-common/    # Shared infrastructure
├── icegate-query/     # Query service (Loki/Prometheus/Tempo APIs)
├── icegate-ingest/    # Ingest service (OTLP)
├── icegate-maintain/  # Maintenance operations
└── icegate-queue/     # Write-ahead log
```

See [Architecture](../architecture/overview.md) for details.

## Pull Request Guidelines

### Before Submitting

1. **Create an issue** first for significant changes
2. **Discuss the approach** before implementation
3. **Run CI checks** locally: `make ci`
4. **Write tests** for new functionality
5. **Update documentation** if needed

### PR Description

Include:

- Summary of changes
- Related issue number
- Testing done
- Breaking changes (if any)

### Review Process

1. Submit PR against `main` branch
2. Wait for CI checks to pass
3. Address review feedback
4. Squash commits if requested
5. Maintainer merges when approved

## Testing

### Running Tests

```bash
# All tests
cargo test

# Specific test
cargo test test_name

# With output
cargo test -- --nocapture

# Integration tests
cargo test --test '*'
```

### Writing Tests

- Unit tests in the same file as implementation
- Integration tests in `tests/` directory
- Use descriptive test names
- Test both success and error cases

## Documentation

### Code Documentation

All public items must have documentation:

```rust
/// Parses a LogQL query string into an AST.
///
/// # Arguments
///
/// * `query` - The LogQL query string
///
/// # Returns
///
/// The parsed LogQL expression or an error
pub fn parse(query: &str) -> Result<LogQLExpr> {
    // ...
}
```

### User Documentation

User docs are in `docs/` using Diplodoc (YFM Markdown).

```bash
# Build docs
cd docs && npm run build

# Serve docs locally
cd docs && npm run serve
```

## Release Process

Releases are created by maintainers:

1. Update version in `Cargo.toml`
2. Update `CHANGELOG.md`
3. Create git tag
4. GitHub Actions builds and publishes

## Getting Help

- **GitHub Issues**: Report bugs and feature requests
- **Discussions**: Ask questions and share ideas

## Code of Conduct

Be respectful and inclusive. We follow the [Rust Code of Conduct](https://www.rust-lang.org/policies/code-of-conduct).

## Next Steps

- Review [Building from Source](building.md)
- Understand [Development Patterns](patterns.md)
- Explore the [Architecture](../architecture/overview.md)

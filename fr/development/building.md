---
title: Compilation
description: Compiler {{product_name}} à partir du code source
---

# Compilation à partir du Code Source

Ce guide couvre la compilation d'{{product_name}} à partir du code source pour le développement et la production.

## Prérequis

### Requis

- **Rust** >= {{rust_version}} (pour le support de l'édition Rust 2024)
- **Cargo** (inclus avec Rust)
- **Git**

### Optionnels

- **Java** (pour la regénération du parser ANTLR)
- **Docker** (pour l'environnement de développement)
- **protoc** (pour la regénération du code protobuf)

## Installer Rust

```bash
# Installation via rustup
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh

# Vérifier l'installation
rustc --version
cargo --version
```

## Cloner le Dépôt

```bash
git clone https://github.com/icegatetech/icegate.git
cd icegate
```

## Compilation

### Build Debug

```bash
cargo build
```

Artefacts de build dans `target/debug/`.

### Build Release

```bash
cargo build --release
```

Artefacts de build dans `target/release/`.

### Binaires Spécifiques

```bash
# Service Query uniquement
cargo build --bin query

# Service Ingest uniquement
cargo build --bin ingest

# Service Maintain uniquement
cargo build --bin maintain
```

## Profils de Build

| Profil | Commande | Cas d'Utilisation |
|--------|----------|-------------------|
| dev | `cargo build` | Développement, débogage |
| release | `cargo build --release` | Production |
| test | `cargo test` | Exécution des tests |
| bench | `cargo bench` | Benchmarks |

### Configuration des Profils

Les profils personnalisés sont dans `Cargo.toml` :

```toml
[profile.release]
opt-level = 3
lto = true
codegen-units = 1

[profile.dev]
opt-level = 0
debug = true
```

## Structure du Workspace

{{product_name}} utilise un workspace Cargo :

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

Compiler des crates individuels :

```bash
cargo build -p icegate-query
cargo build -p icegate-common
```

## Exécution des Services

### Service Query

```bash
cargo run --bin query -- run -c config/docker/query.yaml
```

### Service Ingest

```bash
cargo run --bin ingest -- run -c config/docker/ingest.yaml
```

### Service Maintain

```bash
cargo run --bin maintain -- migrate create -c config/docker/maintain.yaml
```

## Regénération du Parser LogQL

Le parser LogQL est généré à partir de fichiers de grammaire ANTLR4.

### Prérequis

- Java JDK 11+

### Générer le Parser

```bash
cd crates/icegate-query/src/logql

# Installer le jar ANTLR (première fois)
make install

# Regénérer le parser à partir des fichiers .g4
make gen
```

Les fichiers de grammaire sont dans `crates/icegate-query/src/logql/antlr/`.

## Exécution des Tests

```bash
# Tous les tests
cargo test

# Test spécifique
cargo test test_name

# Avec affichage de la sortie
cargo test -- --nocapture

# Mode release (plus rapide mais compilation plus longue)
cargo test --release
```

## Qualité du Code

```bash
# Vérification du formatage
make fmt

# Linting
make clippy

# Audit de sécurité
make audit

# Toutes les vérifications CI
make ci
```

## Résolution de Problèmes de Compilation

### Erreurs de Compilation

1. Vérifiez que la version de Rust est >= {{rust_version}} :

   ```bash
   rustup update
   ```

2. Nettoyez les artefacts de build :

   ```bash
   cargo clean
   cargo build
   ```

### Erreurs d'Édition de Liens

Certaines dépendances nécessitent des bibliothèques système :

**macOS :**

```bash
brew install openssl
```

**Ubuntu/Debian :**

```bash
apt install libssl-dev pkg-config
```

### Mémoire Insuffisante

Les bases de code volumineuses peuvent nécessiter plus de mémoire :

```bash
# Réduire le parallélisme
cargo build -j 2
```

## Build Docker

Construire les images de conteneurs :

```bash
# Build release (multi-arch, cargo-chef en cache)
docker build -t icegate/query:latest \
  --build-arg BINARY=query \
  -f config/docker/release.Dockerfile .

# Build dev (plus simple, single-arch)
docker build -t icegate/query:dev \
  --build-arg BINARY=query \
  --build-arg PROFILE=debug \
  -f config/docker/Dockerfile .
```

## Étapes Suivantes

- Configurer un [Environnement de Développement](setup.md) avec Skaffold ou Docker Compose
- Revoir les [Patterns de Développement](patterns.md)
- Commencer à [Contribuer](contributing.md)

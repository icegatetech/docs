---
title: Contribuer
description: Comment contribuer au développement d'IceGate
---

# Contribuer

Nous accueillons les contributions à IceGate ! Ce guide explique comment commencer.

## Façons de Contribuer

- **Signaler des bugs** via GitHub Issues
- **Demander des fonctionnalités** via GitHub Issues
- **Soumettre des pull requests** pour des corrections de bugs ou des fonctionnalités
- **Améliorer la documentation**
- **Partager vos retours** et cas d'utilisation

## Configuration du Développement

### Prérequis

- Rust >= 1.92.0
- Docker et Docker Compose
- Git

### Cloner et Compiler

```bash
# Cloner le dépôt
git clone https://github.com/icegatetech/icegate.git
cd icegate

# Compiler le projet
cargo build

# Exécuter les tests
cargo test
```

### Démarrer l'Environnement de Développement

```bash
# Recommandé : Skaffold avec Kubernetes local
skaffold dev

# Alternative : Docker Compose avec rechargement à chaud
make dev
```

Voir [Environnement de Développement](setup.md) pour les détails complets sur les profils Skaffold et les options Docker Compose.

## Style de Code

### Formatage

Utilisez rustfmt avec la configuration du projet :

```bash
# Vérifier le formatage
make fmt

# Corriger automatiquement le formatage
make fmt-fix
```

La configuration se trouve dans `rustfmt.toml`.

### Linting

Utilisez clippy avec des paramètres stricts :

```bash
# Exécuter clippy
make clippy

# Corriger automatiquement les problèmes
make clippy-fix
```

La configuration se trouve dans `clippy.toml`.

### Vérifications CI

Avant de soumettre, exécutez toutes les vérifications CI :

```bash
make ci
```

Cela exécute :

1. `cargo check` - vérification de la compilation
2. `cargo fmt -- --check` - vérification du formatage
3. `cargo clippy -- -D warnings` - linting
4. `cargo test` - tests
5. `cargo audit` - audit de sécurité

## Structure du Projet

```
crates/
├── icegate-common/      # Infrastructure partagée (catalogue, stockage, métriques, traçage)
├── icegate-queue/       # Write-ahead log (Parquet sur stockage objet)
├── icegate-query/       # Service Query (APIs Loki/Prometheus/Tempo)
├── icegate-ingest/      # Service Ingest (OTLP HTTP/gRPC)
├── icegate-maintain/    # Opérations de maintenance (migration de schéma)
└── icegate-jobmanager/  # Gestion de l'état des jobs shift
```

Voir l'[Architecture](../architecture/overview.md) pour les détails.

## Directives pour les Pull Requests

### Avant de Soumettre

1. **Créez une issue** d'abord pour les changements significatifs
2. **Discutez de l'approche** avant l'implémentation
3. **Exécutez les vérifications CI** localement : `make ci`
4. **Écrivez des tests** pour les nouvelles fonctionnalités
5. **Mettez à jour la documentation** si nécessaire

### Description de la PR

Incluez :

- Résumé des changements
- Numéro de l'issue associée
- Tests effectués
- Changements incompatibles (le cas échéant)

### Processus de Review

1. Soumettez la PR contre la branche `main`
2. Attendez que les vérifications CI passent
3. Adressez les retours de review
4. Squashez les commits si demandé
5. Le mainteneur merge une fois approuvé

## Tests

### Exécution des Tests

```bash
# Tous les tests
cargo test

# Test spécifique
cargo test test_name

# Avec affichage de la sortie
cargo test -- --nocapture

# Tests d'intégration
cargo test --test '*'
```

### Écriture des Tests

- Tests unitaires dans le même fichier que l'implémentation
- Tests d'intégration dans le répertoire `tests/`
- Utilisez des noms de tests descriptifs
- Testez les cas de succès et d'erreur

## Documentation

### Documentation du Code

Tous les éléments publics doivent avoir une documentation :

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

### Documentation Utilisateur

La documentation utilisateur se trouve dans `docs/` en utilisant Diplodoc (YFM Markdown).

```bash
# Compiler la documentation
cd docs && npm run build

# Servir la documentation localement
cd docs && npm run serve
```

## Processus de Release

Les releases sont créées par les mainteneurs :

1. Mettre à jour la version dans `Cargo.toml`
2. Mettre à jour `CHANGELOG.md`
3. Créer un tag git
4. GitHub Actions compile et publie

## Obtenir de l'Aide

- **GitHub Issues** : Signaler des bugs et demander des fonctionnalités
- **Discussions** : Poser des questions et partager des idées

## Code de Conduite

Soyez respectueux et inclusif. Nous suivons le [Code de Conduite Rust](https://www.rust-lang.org/policies/code-of-conduct).

## Étapes Suivantes

- Revoir la [Compilation](building.md)
- Comprendre les [Patterns de Développement](patterns.md)
- Explorer l'[Architecture](../architecture/overview.md)

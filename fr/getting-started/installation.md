---
title: Installation
description: Installer IceGate et ses dépendances
---

# Installation

Ce guide couvre l'installation d'IceGate et de ses dépendances pour le développement local et les déploiements en production.

## Prérequis

### Outils Requis

- **Rust** >= 1.80.0 (pour le support de l'édition Rust 2024)
- **Cargo** (inclus avec Rust)
- **Git**
- **Docker** et **Docker Compose** (pour l'environnement de développement)

### Outils Optionnels

- **rustfmt** - pour le formatage du code (inclus avec Rust)
- **clippy** - pour l'analyse statique (inclus avec Rust)
- **rust-analyzer** - pour le support IDE

## Vérification des Prérequis

Vérifiez que Rust est installé avec la bonne version :

```bash
# Vérifier la version de Rust
rustc --version

# Vérifier la version de Cargo
cargo --version
```

Vous devez avoir Rust 1.80.0 ou une version ultérieure installée.

## Installation de Rust

Si vous n'avez pas Rust installé, utilisez rustup :

```bash
# Installer Rust via rustup
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh

# Suivre les instructions pour terminer l'installation
# Puis recharger votre shell ou exécuter :
source $HOME/.cargo/env

# Vérifier l'installation
rustc --version
cargo --version
```

## Installation d'IceGate

### À partir du Code Source

Clonez le dépôt et compilez :

```bash
# Cloner le dépôt
git clone https://github.com/icegatetech/icegate.git
cd icegate

# Compiler en mode debug
cargo build

# Ou compiler en mode release (optimisé)
cargo build --release
```

### Docker

La méthode recommandée pour exécuter IceGate en développement est Docker Compose :

```bash
# Démarrer la stack de développement complète
make dev
```

Cela démarre tous les services requis, y compris MinIO (S3), Nessie (catalogue Iceberg), Grafana et le service de requête IceGate.

## Étapes Suivantes

- Continuez vers le [Guide de Démarrage](quickstart.md) pour ingérer vos premières données
- Voir la [Configuration](configuration.md) pour les options de configuration

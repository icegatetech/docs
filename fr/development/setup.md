---
title: Environnement de Développement
description: Configurer un environnement de développement local pour {{product_name}}
---

# Environnement de Développement

Ce guide couvre la configuration d'un environnement de développement local {{product_name}} pour contribuer au code, exécuter les tests et déboguer.

## Prérequis

- **Rust** >= {{rust_version}} (édition Rust 2024)
- **Docker** (pour la construction des images de conteneurs)
- **Git**
- Un cluster Kubernetes local (pour Skaffold)

### Installer Rust

```bash
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
source $HOME/.cargo/env
rustc --version  # Should be >= 1.92.0
```

### Cloner le Dépôt

```bash
git clone https://github.com/icegatetech/icegate.git
cd icegate
```

## Skaffold (Recommandé)

[Skaffold](https://skaffold.dev/) est la méthode recommandée pour développer IceGate. Il compile les images depuis les sources, les déploie sur un cluster Kubernetes local et surveille les modifications de fichiers pour recompiler automatiquement.

### Installer Skaffold

```bash
# macOS
brew install skaffold

# Linux
curl -Lo skaffold https://storage.googleapis.com/skaffold/releases/latest/skaffold-linux-amd64
chmod +x skaffold && sudo mv skaffold /usr/local/bin/
```

### Cluster Kubernetes Local

Vous avez besoin d'un cluster Kubernetes local. Options :

| Runtime | Installation | Notes |
|---------|-------------|-------|
| [OrbStack](https://orbstack.dev/) | macOS uniquement | Léger, démarrage rapide. Utiliser le profil `-p orbstack` |
| [Docker Desktop](https://docs.docker.com/desktop/kubernetes/) | macOS, Windows, Linux | Activer Kubernetes dans les paramètres |
| [minikube](https://minikube.sigs.k8s.io/) | Toutes les plateformes | `minikube start` |
| [kind](https://kind.sigs.k8s.io/) | Toutes les plateformes | `kind create cluster` |

### Exécuter avec Skaffold

```bash
# Profil par défaut (k8s local avec MinIO + Nessie)
skaffold dev

# Profil OrbStack
skaffold dev -p orbstack

# Profil AWS Glue (pousse les images vers le registre)
skaffold dev -p aws-glue

# Profil S3 externe
skaffold dev -p k3s-external-s3
```

### Ce que Skaffold Déploie

Skaffold utilise des overlays Kustomize qui composent plusieurs charts Helm :

**Namespace {{product_name}} (`icegate`) :**

| Composant | Description |
|-----------|-------------|
| `icegate-ingest` | Récepteurs OTLP (gRPC 4317, HTTP 4318) + processus shift |
| `icegate-query` | APIs de requête (Loki 3100, Prometheus 9090, Tempo 3200) |
| `icegate-migrate` | Job de création de schéma (hook Helm pre-install) |

**Namespace Infrastructure (`infra`) :**

| Composant | Description |
|-----------|-------------|
| MinIO | Stockage compatible S3 avec les buckets : `warehouse`, `queue`, `jobs` |
| Nessie | Catalogue Iceberg REST avec persistance RocksDB |

**Namespace Observabilité (`observability`) :**

| Composant | Description |
|-----------|-------------|
| Prometheus | Collecte de métriques (kube-prometheus-stack) |
| Grafana | Tableaux de bord avec panneaux {{product_name}} Ingest et Query pré-configurés |
| Jaeger | Traçage distribué pour les services {{product_name}} |

### Profils Skaffold

| Profil | Overlay | Cas d'utilisation |
|--------|---------|-------------------|
| (défaut) | `skaffold` | Développement local avec MinIO + Nessie |
| `orbstack` | `orbstack` | Kubernetes OrbStack (macOS) |
| `aws-glue` | `aws-glue` | Catalogue AWS Glue (pousse les images) |
| `k3s-external-s3` | `external-s3` | S3 externe + Nessie (pousse les images) |

### Accéder aux Services

```bash
# Rediriger les ports des services IceGate
kubectl port-forward -n icegate svc/icegate-query 3100:3100 &
kubectl port-forward -n icegate svc/icegate-ingest 4318:4318 4317:4317 &

# Rediriger les ports de l'observabilité
kubectl port-forward -n observability svc/grafana 3000:80 &
kubectl port-forward -n observability svc/jaeger-query 16686:16686 &
```

### Modifier le Code

Skaffold surveille le répertoire `crates/` et recompile automatiquement les images lorsque les fichiers changent. Le cycle de recompilation-déploiement prend environ 1 à 2 minutes pour un build release.

Pour itérer plus rapidement sur un service spécifique sans reconstruire les images, vous pouvez exécuter `cargo build` localement et lancer le binaire directement avec un fichier de configuration (voir [Compilation](building.md)).

## Docker Compose (Alternative)

Docker Compose est disponible comme alternative plus simple qui ne nécessite pas Kubernetes.

### Démarrer la Stack de Développement

```bash
# Services principaux avec rechargement à chaud (build debug)
make dev

# Services principaux en mode release
make run-core-release

# Avec générateur de charge
make run-load-release

# Avec monitoring (Jaeger, Prometheus)
make run-monitoring-release

# Avec analytique (Trino SQL)
make run-analytics-release

# Arrêter tous les services
make down
```

### Services Docker Compose

| Service | Port | Description |
|---------|------|-------------|
| MinIO | 9000, 9001 | Stockage compatible S3 + console |
| Nessie | 19120 | Catalogue Iceberg REST |
| Ingest | 4317, 4318 | Récepteurs OTLP gRPC et HTTP |
| Query | 3100, 9090, 3200 | APIs Loki, Prometheus, Tempo |
| Grafana | 3000 | Tableaux de bord |

Les profils Docker Compose ajoutent des services optionnels :

| Profil | Services |
|--------|----------|
| `load` | otelgen (générateur de charge de logs) |
| `monitoring` | Jaeger (16686), Prometheus (9092), node-exporter, cAdvisor |
| `analytics` | Moteur SQL Trino (8082) |

### Build Docker

Construire des images de conteneurs individuelles :

```bash
# En utilisant le Dockerfile release (multi-arch, cargo-chef en cache)
docker build -t icegate/query:latest \
  --build-arg BINARY=query \
  -f config/docker/release.Dockerfile .

# En utilisant le Dockerfile dev (plus simple, single-arch)
docker build -t icegate/query:dev \
  --build-arg BINARY=query \
  --build-arg PROFILE=debug \
  -f config/docker/Dockerfile .
```

## Variables d'Environnement

Pour le développement local avec MinIO :

```bash
export AWS_ACCESS_KEY_ID=minioadmin
export AWS_SECRET_ACCESS_KEY=minioadmin
export AWS_REGION=us-east-1
```

## Étapes Suivantes

- Apprenez à [Compiler depuis les Sources](building.md) et exécuter des services individuels
- Lisez les [Patterns de Développement](patterns.md) pour les conventions de codage
- Voir [Contribuer](contributing.md) pour les directives de PR

---
title: Déploiement
description: Déployez {{product_name}} en production sur Kubernetes ou Docker Compose - arbitrages d'architecture, stockage S3, tolérance aux pannes, supervision et sécurité.
---

# Déploiement

Ce guide couvre le déploiement d'{{product_name}} en environnements de production.

## Prérequis

- **Stockage Objet :** S3, RustFS ou stockage compatible S3
- **Catalogue Iceberg :** le catalogue S3 intégré (par défaut), ou Nessie (REST), AWS S3 Tables ou AWS Glue
- **Docker/Kubernetes :** Pour l'orchestration des conteneurs

## Considérations d'Architecture

### Mise à l'Échelle des Composants

| Composant | Mise à l'Échelle | Notes |
|-----------|-----------------|-------|
| Ingest | Horizontale | Mise à l'échelle pour le débit d'écriture |
| Query | Horizontale | Mise à l'échelle pour la concurrence des requêtes |
| Maintain | Horizontale | Les workers se coordonnent via l'état des jobs dans le stockage objet (compare-and-swap) |

### Exigences en Ressources

**Service Ingest (par réplica) :**

- CPU : 2-4 cœurs
- Mémoire : 4-8 Go
- Disque : Minimal (écrit sur le stockage objet)

**Service Query (par réplica) :**

- CPU : 4-8 cœurs
- Mémoire : 8-32 Go (dépend de la complexité des requêtes)
- Disque : SSD recommandé pour le cache (`catalog.cache.disk_dir`)

**Service Maintain :**

- CPU : 2-4 cœurs
- Mémoire : 4-8 Go
- Disque : SSD pour les fichiers temporaires de compaction

## Déploiement Docker Compose

### Profils Docker Compose

Le projet inclut des profils Docker Compose pour différents scénarios de déploiement :

```bash
# Services principaux : RustFS, Ingest, Query, Maintain
make run-core-release

# Services principaux + générateur de charge pour les tests
make run-load-release

# Services principaux + monitoring (Jaeger, Prometheus, Grafana)
# Services principaux + analytics (Trino)
make run-analytics-release
```

### Configuration de Production

```yaml
# docker-compose.yml
services:
  rustfs:
    image: rustfs/rustfs:1.0.0-beta.8
    environment:
      RUSTFS_ACCESS_KEY: ${S3_ACCESS_KEY}
      RUSTFS_SECRET_KEY: ${S3_SECRET_KEY}
      RUSTFS_VOLUMES: /data
      RUSTFS_CONSOLE_ENABLE: "true"
      RUSTFS_CONSOLE_ADDRESS: "0.0.0.0:9001"
    volumes:
      - rustfs-data:/data
    ports:
      - "9000:9000"   # S3 API
      - "9001:9001"   # Console

  ingest:
    image: icegate/ingest:latest
    command: run -c /etc/icegate/ingest.yaml
    environment:
      AWS_ACCESS_KEY_ID: ${S3_ACCESS_KEY}
      AWS_SECRET_ACCESS_KEY: ${S3_SECRET_KEY}
    volumes:
      - ./config/ingest.yaml:/etc/icegate/ingest.yaml:ro
    ports:
      - "4317:4317"   # OTLP gRPC
      - "4318:4318"   # OTLP HTTP
      - "9091:9091"   # Prometheus metrics
    depends_on:
      - rustfs

  query:
    image: icegate/query:latest
    command: run -c /etc/icegate/query.yaml
    environment:
      AWS_ACCESS_KEY_ID: ${S3_ACCESS_KEY}
      AWS_SECRET_ACCESS_KEY: ${S3_SECRET_KEY}
    volumes:
      - ./config/query.yaml:/etc/icegate/query.yaml:ro
      - query-cache:/tmp/icegate/cache
    ports:
      - "3100:3100"   # Loki API
      - "9090:9090"   # Prometheus API
      - "3200:3200"   # Tempo API
      - "8815:8815"   # Arrow Flight SQL
    depends_on:
      - rustfs

  maintain:
    image: icegate/maintain:latest
    environment:
      AWS_ACCESS_KEY_ID: ${S3_ACCESS_KEY}
      AWS_SECRET_ACCESS_KEY: ${S3_SECRET_KEY}
    volumes:
      - ./config/maintain.yaml:/etc/icegate/maintain.yaml:ro
    depends_on:
      - rustfs

volumes:
  rustfs-data:
  query-cache:
```

### Build Docker

Construire les images de conteneurs à partir des sources :

```bash
# Build du service ingest (mode release)
docker build -t icegate/ingest:latest \
  --build-arg BINARY=ingest \
  --build-arg PROFILE=release \
  -f config/docker/Dockerfile .

# Build du service query
docker build -t icegate/query:latest \
  --build-arg BINARY=query \
  --build-arg PROFILE=release \
  -f config/docker/Dockerfile .

# Build du service maintain
docker build -t icegate/maintain:latest \
  --build-arg BINARY=maintain \
  --build-arg PROFILE=release \
  -f config/docker/Dockerfile .
```

## Déploiement Kubernetes

### Helm Charts

{{product_name}} inclut des Helm charts pour le déploiement Kubernetes :

```bash
# Installation depuis les charts locaux
helm install icegate ./config/helm/icegate

# Avec des valeurs personnalisées
helm install icegate ./config/helm/icegate \
  -f my-values.yaml \
  --set storage.bucket=my-warehouse
```

### Overlays Kustomize

Des overlays Kustomize pré-construits sont disponibles pour les scénarios courants :

| Overlay | Description |
|---------|-------------|
| `skaffold` | Développement local avec Skaffold |
| `orbstack` | Runtime de conteneurs OrbStack |
| `aws-glue` | Intégration avec le catalogue AWS Glue |
| `aws-s3tables` | Intégration du catalogue AWS S3 Tables |
| `external-s3` | Stockage S3 externe avec un catalogue Nessie |

```bash
# Appliquer avec kustomize
kubectl apply -k config/kustomize/overlays/aws-glue
```

## Configuration du Stockage S3

### AWS S3

```yaml
storage:
  backend: !s3
    bucket: icegate-warehouse
    region: us-east-1
```

### RustFS (compatible S3)

```yaml
storage:
  backend: !s3
    bucket: warehouse
    endpoint: http://rustfs:9000
    region: us-east-1
```

## Haute Disponibilité

### Déploiement Multi-Zone

Déployer les services sur plusieurs zones de disponibilité :

```yaml
services:
  query:
    deploy:
      replicas: 3
      placement:
        constraints:
          - node.labels.zone != ${ZONE}
```

### Vérifications de Santé

Tous les services exposent des points de terminaison de santé :

- Ingest : `GET /health` (port 4318)
- Query : `GET /ready` (port 3100)

## Monitoring

### Métriques

Les services {{product_name}} exposent des métriques Prometheus sur un port dédié (par défaut : 9091) :

- Métriques Ingest : `http://ingest:9091/metrics`
- Métriques Query : `http://query:9091/metrics`

Configuration dans chaque service :

```yaml
metrics:
  enabled: true
  host: 0.0.0.0
  port: 9091
  path: /metrics
```

### Auto-Observabilité avec le Traçage

{{product_name}} peut exporter ses propres traces via OTLP pour le débogage :

```yaml
tracing:
  enabled: true
  service_name: icegate-query
  otlp_endpoint: http://jaeger:4317
  sample_ratio: 0.1  # 10% sampling in production

```

### Journalisation

Les services écrivent les logs sur stdout. Configurez le niveau de log via la variable d'environnement `RUST_LOG` :

```yaml
environment:
  RUST_LOG: "info,icegate_query=debug"
```

## Sécurité

### Sécurité Réseau

- Utilisez TLS pour toutes les connexions externes
- Restreignez l'accès au stockage objet et à tout catalogue externe au réseau interne uniquement
- Utilisez des politiques réseau dans Kubernetes

### Authentification

Configurez l'authentification des tenants via un reverse proxy ou une passerelle API :

```nginx
location /loki/ {
    auth_request /auth;
    proxy_set_header X-Scope-OrgID $remote_user;
    proxy_pass http://query:3100/;
}
```

## Étapes Suivantes

- Configurer les opérations de [Maintenance](maintenance.md)
- Mettre en place les procédures de [Dépannage](troubleshooting.md)
- Revoir l'[Architecture](../architecture/overview.md) pour les décisions de mise à l'échelle

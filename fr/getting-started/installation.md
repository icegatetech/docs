---
title: Installation
description: Installer {{product_name}} sur Kubernetes avec Helm
---

# Installation

{{product_name}} est déployé sur Kubernetes en utilisant des charts Helm, avec des overlays Kustomize pour les personnalisations spécifiques à l'environnement.

## Prérequis

- **Kubernetes** >= 1.28 avec **Helm 3**
- **Stockage objet :** AWS S3 ou compatible S3 (RustFS)
- **Catalogue Iceberg :** le catalogue S3 intégré (par défaut, sans service externe), ou Nessie (REST), AWS S3 Tables ou AWS Glue

## Helm Chart

Le chart Helm déploie tous les composants {{product_name}} : Ingest, Query et un job Migrate (création du schéma en tant que hook pre-install/pre-upgrade).

### Installation depuis le registre OCI

```bash
helm install icegate oci://ghcr.io/icegatetech/charts/icegate \
  --version 0.1.0 \
  --namespace icegate \
  --create-namespace \
  -f values.yaml
```

### Installation depuis les charts locaux

```bash
git clone https://github.com/icegatetech/icegate.git
helm install icegate ./icegate/config/helm/icegate \
  --namespace icegate \
  --create-namespace \
  -f values.yaml
```

### Fichier values.yaml minimal

{% note info %}

Les valeurs Helm utilisent le camelCase et des clés plates (ex. `backend: rest` + `rest.uri`). Le chart traduit ces valeurs dans le format natif de configuration serde tagged enum (`backend: !rest`) attendu par les binaires IceGate. Voir [Configuration](configuration.md) pour la référence de configuration native.

{% endnote %}

Un fichier `values.yaml` minimal pour un catalogue REST (Nessie) avec stockage compatible S3 :

```yaml
catalog:
  backend: rest
  rest:
    uri: http://nessie:19120/iceberg
  warehouse: "s3://warehouse/"

storage:
  s3:
    bucket: warehouse
    region: us-east-1
    endpoint: "http://rustfs:9000"

queue:
  common:
    basePath: "s3://queue/"

aws:
  existingSecret: icegate-aws-credentials
  region: us-east-1
```

### Catalogue AWS Glue

```yaml
catalog:
  backend: glue
  glue:
    catalogId: "123456789012"
  warehouse: "s3://my-bucket/warehouse/"

storage:
  s3:
    bucket: my-bucket
    region: eu-central-1

aws:
  existingSecret: icegate-aws-credentials
  region: eu-central-1
```

### Catalogue AWS S3 Tables

```yaml
catalog:
  backend: s3tables
  s3tables:
    tableBucketArn: "arn:aws:s3tables:eu-central-1:123456789012:bucket/my-tables"

storage:
  s3:
    region: eu-central-1

aws:
  existingSecret: icegate-aws-credentials
  region: eu-central-1
```

### Principales valeurs Helm

| Valeur | Défaut | Description |
|--------|--------|-------------|
| `catalog.backend` | `s3` | Type de catalogue : `s3`, `rest`, `s3tables` ou `glue` |
| `storage.s3.bucket` | `warehouse` | Nom du bucket S3 |
| `storage.s3.endpoint` | `""` | Endpoint S3 personnalisé (RustFS). Omettre pour AWS S3 réel |
| `aws.existingSecret` | `""` | Secret contenant les clés `aws-access-key-id` et `aws-secret-access-key` |
| `query.replicaCount` | `1` | Réplicas du service Query |
| `ingest.replicaCount` | `1` | Réplicas du service Ingest |
| `query.cache.enabled` | `true` | Activer le cache hybride disque+mémoire pour les lectures de requêtes |
| `query.engine.walQueryEnabled` | `false` | Inclure les données WAL dans les résultats de requête pour un accès temps réel |
| `serviceMonitor.enabled` | `false` | Créer des ressources Prometheus ServiceMonitor |
| `migrate.enabled` | `true` | Exécuter la migration de schéma en tant que hook Helm |

### Images de conteneurs

| Composant | Image |
|-----------|-------|
| Query | `ghcr.io/icegatetech/icegate-query` |
| Ingest | `ghcr.io/icegatetech/icegate-ingest` |
| Migrate | `ghcr.io/icegatetech/icegate-maintain` |

## Overlays Kustomize

Pour les personnalisations spécifiques à l'environnement, {{product_name}} fournit des overlays Kustomize qui composent le chart Helm avec les dépendances d'infrastructure.

### Overlays disponibles

| Overlay | Description | Infrastructure |
|---------|-------------|----------------|
| `skaffold` | Développement local avec Skaffold | RustFS, stack d'observabilité |
| `orbstack` | Runtime de conteneurs OrbStack | RustFS, stack d'observabilité |
| `aws-glue` | Catalogue AWS Glue | Stack d'observabilité (S3 externe) |
| `aws-s3tables` | Catalogue AWS S3 Tables | Stack d'observabilité (S3 externe) |
| `external-s3` | S3 externe + catalogue Nessie | Nessie, stack d'observabilité |

Tous les overlays partagent une base commune (`config/kustomize/base/`) qui déploie la stack d'observabilité : Prometheus (kube-prometheus-stack), Grafana avec des tableaux de bord {{product_name}} pré-configurés et Jaeger pour le traçage distribué.

### Utilisation

```bash
# Appliquer un overlay directement
kubectl apply -k config/kustomize/overlays/aws-glue

# Ou utiliser Skaffold pour le développement (voir Environnement de Développement)
skaffold dev
```

### Personnalisation d'un overlay

Chaque overlay contient :

- `kustomization.yaml` — déclare les charts Helm et les patches
- `values-icegate.yaml` — valeurs Helm {{product_name}} pour cet environnement
- `secret-aws.yaml` — Secret des identifiants AWS (à modifier avant application)

Pour créer un overlay personnalisé :

```bash
cp -r config/kustomize/overlays/orbstack config/kustomize/overlays/my-env
vi config/kustomize/overlays/my-env/values-icegate.yaml
vi config/kustomize/overlays/my-env/secret-aws.yaml
kubectl apply -k config/kustomize/overlays/my-env
```

## Vérification de l'installation

```bash
# Vérifier que les pods sont en cours d'exécution
kubectl get pods -n icegate

# Rediriger le port vers le service Query
kubectl port-forward -n icegate svc/icegate-query 3100:3100

# Tester la disponibilité
curl http://localhost:3100/ready
```

## Étapes Suivantes

- Continuez vers le [Guide de Démarrage](quickstart.md) pour ingérer vos premières données
- Voir la [Configuration](configuration.md) pour les options de configuration détaillées
- Configurer un [Environnement de Développement](../development/setup.md) pour contribuer

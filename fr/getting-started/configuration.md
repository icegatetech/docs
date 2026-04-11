---
title: Configuration
description: Configurer les composants IceGate
---

# Configuration

{{product_name}} utilise des fichiers de configuration YAML ou TOML. Le format est auto-détecté par l'extension du fichier (`.yaml`/`.yml` pour YAML, `.toml` pour TOML).

## Utilisation CLI

Chaque binaire accepte un fichier de configuration via le flag `-c` / `--config` :

```bash
# Service Ingest
ingest run -c /etc/icegate/ingest.yaml

# Service Query
query run -c /etc/icegate/query.yaml

# Service Maintain (migration de schéma)
maintain migrate create -c /etc/icegate/maintain.yaml
maintain migrate upgrade -c /etc/icegate/maintain.yaml

# Afficher la version
ingest version
query version
```

## Variables d'Environnement

| Variable | Description | Défaut |
|----------|-------------|--------|
| `AWS_ACCESS_KEY_ID` | Clé d'accès S3 (utilisée par le stockage et le job manager) | — |
| `AWS_SECRET_ACCESS_KEY` | Clé secrète S3 | — |
| `OTEL_EXPORTER_OTLP_ENDPOINT` | Point de terminaison de traçage OpenTelemetry (fallback si `tracing.otlp_endpoint` non défini) | — |
| `RUST_LOG` | Filtre de niveau de log (ex. `info`, `debug`, `info,icegate_query=debug`) | `info` |

## Configuration du Catalogue

La section `catalog` configure le catalogue Apache Iceberg. Elle est partagée par tous les services (Ingest, Query, Maintain).

```yaml
catalog:
  backend: !rest
    uri: http://nessie:19120/iceberg
  warehouse: s3://warehouse/
  properties:
    prefix: main
```

### Paramètres du Catalogue

| Paramètre | Type | Requis | Défaut | Description |
|-----------|------|--------|--------|-------------|
| `backend` | enum | Oui | `memory` | Type de backend du catalogue (voir ci-dessous) |
| `warehouse` | string | Oui | — | Emplacement de l'entrepôt (ex. `s3://warehouse/`) |
| `properties` | map | Non | `{}` | Propriétés supplémentaires spécifiques au catalogue |
| `cache` | object | Non | — | Configuration du cache IO (voir [Configuration du Cache](#configuration-du-cache)) |

### Backends du Catalogue

#### REST Catalog (Nessie)

```yaml
catalog:
  backend: !rest
    uri: http://nessie:19120/iceberg
  warehouse: s3://warehouse/
  properties:
    prefix: main
```

| Paramètre | Type | Requis | Description |
|-----------|------|--------|-------------|
| `uri` | string | Oui | URL du point de terminaison REST du catalogue (doit commencer par `http://` ou `https://`) |

#### AWS S3 Tables

```yaml
catalog:
  backend: !s3tables
    table_bucket_arn: arn:aws:s3tables:us-east-1:123456789012:bucket/my-tables
  warehouse: s3://warehouse/
```

| Paramètre | Type | Requis | Description |
|-----------|------|--------|-------------|
| `table_bucket_arn` | string | Oui | ARN du bucket S3 Tables (format : `arn:aws:s3tables:<region>:<account>:bucket/<name>`) |

#### AWS Glue

```yaml
catalog:
  backend: !glue
    catalog_id: "123456789012"
  warehouse: s3://warehouse/
```

| Paramètre | Type | Requis | Description |
|-----------|------|--------|-------------|
| `catalog_id` | string | Non | Identifiant de compte AWS à 12 chiffres. Quand omis, le catalogue par défaut du compte est utilisé |

#### En Mémoire (Test)

```yaml
catalog:
  backend: !memory
  warehouse: /tmp/icegate/warehouse
```

### Configuration du Cache

La section optionnelle `cache` active un cache hybride foyer (mémoire + disque) pour réduire les allers-retours S3 sur les lectures répétées. Recommandé pour les services query en production.

```yaml
catalog:
  backend: !rest
    uri: http://nessie:19120/iceberg
  warehouse: s3://warehouse/
  cache:
    memory_size_mb: 1024
    disk_dir: /tmp/icegate/cache
    disk_size_mb: 4096
    stat_ttl_secs: 300
    max_write_cache_size_mb: 128
    prefetch:
      max_prefetch_bytes: 1048576
```

| Paramètre | Type | Requis | Défaut | Description |
|-----------|------|--------|--------|-------------|
| `memory_size_mb` | integer | Oui | — | Capacité du cache mémoire en MiB |
| `disk_dir` | string | Oui | — | Répertoire pour le stockage du cache disque |
| `disk_size_mb` | integer | Oui | — | Capacité du cache disque en MiB |
| `stat_ttl_secs` | integer | Non | — | TTL en secondes pour le cache des réponses S3 HEAD |
| `max_write_cache_size_mb` | integer | Non | — | Taille maximale en MiB des valeurs mises en cache à l'écriture. Les fichiers plus volumineux contournent le cache |
| `prefetch.max_prefetch_bytes` | integer | Non | — | Nombre maximum d'octets à pré-charger pour les blocs de colonnes Parquet |

## Configuration du Stockage

La section `storage` configure le backend de stockage objet. Partagée par tous les services.

### S3 / Compatible S3 (MinIO)

```yaml
storage:
  backend: !s3
    bucket: warehouse
    region: us-east-1
    endpoint: http://minio:9000
```

| Paramètre | Type | Requis | Défaut | Description |
|-----------|------|--------|--------|-------------|
| `bucket` | string | Oui | — | Nom du bucket S3 |
| `region` | string | Oui | — | Région AWS |
| `endpoint` | string | Non | — | URL de point de terminaison personnalisée pour le stockage compatible S3 (MinIO, etc.) |

### Système de Fichiers Local

```yaml
storage:
  backend: !filesystem
    root_path: /var/data/icegate
```

| Paramètre | Type | Requis | Description |
|-----------|------|--------|-------------|
| `root_path` | string | Oui | Répertoire racine pour le stockage des données |

### En Mémoire (Test)

```yaml
storage:
  backend: !memory
```

## Configuration du Service Ingest

Référence complète pour le service Ingest (`ingest run -c ingest.yaml`).

### Exemple Complet

```yaml
catalog:
  backend: !rest
    uri: http://nessie:19120/iceberg
  warehouse: s3://warehouse/
  properties:
    prefix: main

storage:
  backend: !s3
    bucket: warehouse
    region: us-east-1
    endpoint: http://minio:9000

queue:
  common:
    base_path: s3://queue/
    channel_capacity: 1024
    max_row_group_size: 8192
  write:
    write_retries: 5
    compression: zstd
    records_per_flush_multiplier: 1
    max_bytes_per_flush: 67108864
    flush_interval_ms: 200

shift:
  read:
    max_record_batches_per_task: 1024
    max_input_bytes_per_task: 67108864
    plan_segment_read_parallelism: 8
    shift_segment_read_parallelism: 8
  write:
    row_group_size: 8192
    max_file_size_mb: 64
    table_cache_ttl_secs: 60
  jobsmanager:
    worker_count: 4
    poll_interval_ms: 1000
    iteration_interval_millisecs: 30000
    storage:
      endpoint: http://minio:9000
      bucket: jobs
      prefix: shifter
      region: us-east-1
      use_ssl: false
      job_state_codec: json
      request_timeout_secs: 5

otlp_http:
  enabled: true
  host: 0.0.0.0
  port: 4318

otlp_grpc:
  enabled: true
  host: 0.0.0.0
  port: 4317

metrics:
  enabled: true
  host: 0.0.0.0
  port: 9091
  path: /metrics

tracing:
  enabled: true
  service_name: icegate-ingest
  otlp_endpoint: http://jaeger:4317
  sample_ratio: 1.0
```

### Récepteurs OTLP

| Paramètre | Type | Défaut | Description |
|-----------|------|--------|-------------|
| `otlp_http.enabled` | bool | `true` | Activer le récepteur OTLP HTTP |
| `otlp_http.host` | string | `0.0.0.0` | Adresse d'écoute |
| `otlp_http.port` | integer | `4318` | Port HTTP (standard OTLP) |
| `otlp_grpc.enabled` | bool | `true` | Activer le récepteur OTLP gRPC |
| `otlp_grpc.host` | string | `0.0.0.0` | Adresse d'écoute |
| `otlp_grpc.port` | integer | `4317` | Port gRPC (standard OTLP) |

### Configuration de la File d'Attente (WAL)

Contrôle la manière dont les données entrantes sont écrites dans le Write-Ahead Log.

| Paramètre | Type | Défaut | Description |
|-----------|------|--------|-------------|
| `queue.common.base_path` | string | — | Chemin de base pour les segments WAL (ex. `s3://queue/`) |
| `queue.common.channel_capacity` | integer | `1024` | Capacité du canal borné pour la contre-pression |
| `queue.common.max_row_group_size` | integer | `8192` | Nombre maximum de lignes par groupe de lignes Parquet |
| `queue.write.write_retries` | integer | `5` | Nombre de tentatives de réessai pour les opérations d'écriture |
| `queue.write.compression` | enum | `zstd` | Compression Parquet : `none`, `snappy`, `gzip`, `lzo`, `brotli`, `lz4`, `zstd` |
| `queue.write.records_per_flush_multiplier` | integer | `1` | Groupes de lignes à accumuler avant le flush |
| `queue.write.max_bytes_per_flush` | integer | `67108864` | Nombre maximum d'octets (64 MiB) avant le flush |
| `queue.write.flush_interval_ms` | integer | `200` | Temps maximum en ms avant le flush |
| `queue.read.metadata_entries_cache_capacity` | integer | `2048` | Taille du cache LRU pour les entrées de métadonnées Parquet |

### Configuration du Shift (WAL → Iceberg)

Contrôle la manière dont les données WAL sont compactées et écrites dans les tables Iceberg.

| Paramètre | Type | Défaut | Description |
|-----------|------|--------|-------------|
| `shift.read.max_record_batches_per_task` | integer | `1024` | Nombre maximum de groupes de lignes par tâche shift |
| `shift.read.max_input_bytes_per_task` | integer | `67108864` | Nombre maximum d'octets en entrée (64 MiB) par tâche shift |
| `shift.read.plan_segment_read_parallelism` | integer | `8` | Lectures parallèles des segments WAL pendant la planification |
| `shift.read.shift_segment_read_parallelism` | integer | `8` | Lectures parallèles des segments WAL pendant le shift |
| `shift.write.row_group_size` | integer | `8192` | Lignes par groupe de lignes Parquet Iceberg |
| `shift.write.max_file_size_mb` | integer | `64` | Taille maximale des fichiers de données Iceberg en MiB |
| `shift.write.table_cache_ttl_secs` | integer | `60` | TTL pour les métadonnées de table Iceberg en cache |
| `shift.jobsmanager.worker_count` | integer | `CPUs/2` | Nombre de workers du job manager |
| `shift.jobsmanager.poll_interval_ms` | integer | `1000` | Intervalle de sondage pour les workers |
| `shift.jobsmanager.iteration_interval_millisecs` | integer | `30000` | Intervalle entre les itérations de jobs |

### Stockage du Job Manager

Le job manager stocke l'état des jobs shift dans un bucket S3 séparé.

| Paramètre | Type | Défaut | Description |
|-----------|------|--------|-------------|
| `shift.jobsmanager.storage.endpoint` | string | — | URL du point de terminaison S3 |
| `shift.jobsmanager.storage.bucket` | string | — | Nom du bucket pour l'état des jobs |
| `shift.jobsmanager.storage.prefix` | string | `shifter` | Préfixe de clé d'objet |
| `shift.jobsmanager.storage.region` | string | `us-east-1` | Région AWS |
| `shift.jobsmanager.storage.use_ssl` | bool | `false` | Utiliser HTTPS pour le point de terminaison |
| `shift.jobsmanager.storage.job_state_codec` | enum | `json` | Format de sérialisation : `json` ou `cbor` |
| `shift.jobsmanager.storage.request_timeout_secs` | integer | `5` | Timeout des requêtes S3 en secondes |
| `shift.jobsmanager.storage.access_key_id` | string | — | Clé d'accès S3 (fallback vers la variable d'environnement `AWS_ACCESS_KEY_ID`) |
| `shift.jobsmanager.storage.secret_access_key` | string | — | Clé secrète S3 (fallback vers la variable d'environnement `AWS_SECRET_ACCESS_KEY`) |

## Configuration du Service Query

Référence complète pour le service Query (`query run -c query.yaml`).

### Exemple Complet

```yaml
catalog:
  backend: !rest
    uri: http://nessie:19120/iceberg
  warehouse: s3://warehouse/
  properties:
    prefix: main
  cache:
    memory_size_mb: 1024
    disk_dir: /tmp/icegate/cache
    disk_size_mb: 4096

storage:
  backend: !s3
    bucket: warehouse
    region: us-east-1
    endpoint: http://minio:9000

engine:
  batch_size: 8192
  target_partitions: 4
  catalog_name: iceberg
  refresh_interval_secs: 15
  max_age_secs: 30
  wal_query_enabled: false
  wal_metadata_size_hint: 65536

queue:
  common:
    base_path: s3://queue/

loki:
  enabled: true
  host: 0.0.0.0
  port: 3100

prometheus:
  enabled: true
  host: 0.0.0.0
  port: 9090

tempo:
  enabled: true
  host: 0.0.0.0
  port: 3200

metrics:
  enabled: true
  host: 0.0.0.0
  port: 9091
  path: /metrics

tracing:
  enabled: true
  service_name: icegate-query
  otlp_endpoint: http://jaeger:4317
  sample_ratio: 1.0
```

### Moteur de Requêtes

| Paramètre | Type | Défaut | Description |
|-----------|------|--------|-------------|
| `engine.batch_size` | integer | `8192` | Taille de lot DataFusion (lignes traitées à la fois) |
| `engine.target_partitions` | integer | `4` | Partitions d'exécution parallèle (régler au nombre de cœurs CPU) |
| `engine.catalog_name` | string | `iceberg` | Nom du catalogue en SQL (ex. `SELECT * FROM iceberg.icegate.logs`) |
| `engine.refresh_interval_secs` | integer | `15` | Intervalle de rafraîchissement en arrière-plan des métadonnées du catalogue |
| `engine.max_age_secs` | integer | `30` | Âge maximum avant que le catalogue en cache soit considéré obsolète. Doit être >= `refresh_interval_secs` |
| `engine.wal_query_enabled` | bool | `false` | Inclure les données WAL (chaudes) dans les résultats de requête pour un accès en temps réel |
| `engine.wal_metadata_size_hint` | integer | `65536` | Octets à lire depuis la fin du fichier en une requête pour le footer WAL. Définir à `null` pour la valeur par défaut de DataFusion |

{% note info "Requêtes en Temps Réel avec WAL" %}

Lorsque `engine.wal_query_enabled` est `true`, le service query lit à la fois les données Iceberg validées et les segments WAL non validés. Cela permet d'interroger des données vieilles de quelques secondes seulement, avant qu'elles n'aient été transférées vers les tables Iceberg.

**Note :** Les points de terminaison de métadonnées `/labels`, `/label/{name}/values` et `/series` lisent toujours uniquement depuis Iceberg, quel que soit ce paramètre.

{% endnote %}

### Serveurs API Query

| Paramètre | Type | Défaut | Description |
|-----------|------|--------|-------------|
| `loki.enabled` | bool | `true` | Activer l'API de requête de logs compatible Loki |
| `loki.host` | string | `0.0.0.0` | Adresse d'écoute |
| `loki.port` | integer | `3100` | Port de l'API Loki |
| `prometheus.enabled` | bool | `true` | Activer l'API de métriques compatible Prometheus |
| `prometheus.host` | string | `0.0.0.0` | Adresse d'écoute |
| `prometheus.port` | integer | `9090` | Port de l'API Prometheus |
| `tempo.enabled` | bool | `true` | Activer l'API de traces compatible Tempo |
| `tempo.host` | string | `0.0.0.0` | Adresse d'écoute |
| `tempo.port` | integer | `3200` | Port de l'API Tempo |

## Configuration du Service Maintain

Le service Maintain nécessite uniquement la configuration du catalogue et du stockage :

```yaml
catalog:
  backend: !rest
    uri: http://nessie:19120/iceberg
  warehouse: s3://warehouse/
  properties:
    prefix: main

storage:
  backend: !s3
    bucket: warehouse
    region: us-east-1
    endpoint: http://minio:9000
```

### CLI Maintain

```bash
# Créer toutes les tables Iceberg (première installation)
maintain migrate create -c maintain.yaml

# Mettre à niveau les schémas de tables existants
maintain migrate upgrade -c maintain.yaml

# Exécution à blanc (affiche ce qui serait fait)
maintain migrate create -c maintain.yaml --dry-run
maintain migrate upgrade -c maintain.yaml --dry-run
```

## Configuration des Métriques

Tous les services exposent des métriques Prometheus via un serveur HTTP dédié.

| Paramètre | Type | Défaut | Description |
|-----------|------|--------|-------------|
| `metrics.enabled` | bool | `false` | Activer le point de terminaison des métriques Prometheus |
| `metrics.host` | string | `127.0.0.1` | Adresse d'écoute |
| `metrics.port` | integer | `9091` | Port du serveur de métriques |
| `metrics.path` | string | `/metrics` | Chemin URL pour les métriques |

## Configuration du Traçage

Tous les services peuvent exporter des traces OpenTelemetry pour l'auto-observabilité.

| Paramètre | Type | Défaut | Description |
|-----------|------|--------|-------------|
| `tracing.enabled` | bool | `true` | Activer le traçage |
| `tracing.service_name` | string | — | Nom du service pour les traces |
| `tracing.otlp_endpoint` | string | — | URL du point de terminaison OTLP. Fallback vers la variable d'environnement `OTEL_EXPORTER_OTLP_ENDPOINT` |
| `tracing.sample_ratio` | float | `1.0` | Ratio d'échantillonnage (0.0 à 1.0). Réduire en production |

Exemple avec Jaeger :

```yaml
tracing:
  enabled: true
  service_name: icegate-ingest
  otlp_endpoint: http://jaeger:4317
  sample_ratio: 0.1  # Sample 10% of traces in production

```

## Environnement de Développement

Pour le développement local, utilisez la configuration Docker Compose fournie :

```bash
# Démarrer les services principaux avec hot-reload
make dev

# Démarrer les services principaux en mode release
make run-core-release

# Démarrer avec le générateur de charge
make run-load-release

# Démarrer avec le monitoring (Jaeger, Prometheus, Grafana)
make run-analytics-release
```

Variables d'environnement pour le développement local :

```bash
export AWS_ACCESS_KEY_ID=minioadmin
export AWS_SECRET_ACCESS_KEY=minioadmin
export AWS_REGION=us-east-1
```

## Étapes Suivantes

- En savoir plus sur l'[Ingestion de Données](../guides/ingestion.md)
- Explorer les capacités de [Requêtes](../guides/querying.md)
- Configurer le [Multi-Tenancy](../guides/multi-tenancy.md)

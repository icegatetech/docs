---
title: Maintenance
description: Maintenir IceGate pour des performances optimales
---

# Maintenance

Ce guide couvre les opérations de maintenance courantes pour IceGate.

## Migration de Schéma

### Configuration Initiale

Créer toutes les tables Iceberg pour la première fois :

```bash
maintain migrate create -c maintain.yaml
```

### Mises à Niveau de Schéma

Mettre à niveau les schémas de tables existants lors de la mise à jour d'IceGate :

```bash
maintain migrate upgrade -c maintain.yaml
```

### Exécution à Blanc

Prévisualiser ce qui serait fait sans exécuter :

```bash
maintain migrate create -c maintain.yaml --dry-run
maintain migrate upgrade -c maintain.yaml --dry-run
```

### Processus de Migration

1. Connexion au catalogue Iceberg
2. Vérification des schémas de tables existants
3. Création des tables manquantes (ou modification des tables existantes)
4. Rapport sur l'état de la migration

## Compaction des Données (Shift)

Le service Ingest transfère automatiquement les données WAL vers des tables Iceberg optimisées via le processus shift intégré.

### Fonctionnement du Shift

1. Le job manager surveille les segments WAL
2. Regroupe les segments en tâches shift
3. Lit les fichiers WAL Parquet en parallèle
4. Fusionne et re-partitionne les données
5. Écrit les fichiers de données Iceberg optimisés
6. Valide un nouveau snapshot dans le catalogue
7. Supprime les segments WAL traités

### Optimisation des Performances du Shift

Paramètres de configuration clés dans la configuration du service Ingest :

```yaml
shift:
  read:
    max_record_batches_per_task: 1024
    max_input_bytes_per_task: 67108864  # 64 MiB
    plan_segment_read_parallelism: 8
    shift_segment_read_parallelism: 8
  write:
    row_group_size: 8192
    max_file_size_mb: 64
    table_cache_ttl_secs: 60
  jobsmanager:
    worker_count: 4           # Half of available CPUs by default
    poll_interval_ms: 1000
    iteration_interval_millisecs: 30000
```

Voir [Configuration](../getting-started/configuration.md#shift-wal--iceberg-configuration) pour la référence complète des paramètres.

## Optimisation des Tables

### Optimiser la Taille des Fichiers

Réécrire les petits fichiers en fichiers plus grands et optimisés :

```sql
ALTER TABLE icegate.logs EXECUTE optimize;
```

### Expirer les Snapshots

Supprimer les anciens snapshots pour récupérer de l'espace de stockage :

```sql
ALTER TABLE icegate.logs
EXECUTE expire_snapshots(retention_threshold => '7d');
```

### Supprimer les Fichiers Orphelins

Supprimer les fichiers de données non référencés :

```sql
ALTER TABLE icegate.logs
EXECUTE remove_orphan_files(retention_threshold => '1d');
```

## Rétention des Données

### Suppression Manuelle

Supprimer les données antérieures à une date spécifique :

```sql
DELETE FROM icegate.logs
WHERE timestamp < TIMESTAMP '2024-01-01 00:00:00 UTC';
```

## Monitoring

### Métriques Clés

Surveillez ces métriques pour la santé de la maintenance (disponibles sur `http://ingest:9091/metrics`) :

| Métrique | Description | Seuil d'Alerte |
|----------|-------------|----------------|
| Nombre de fichiers WAL | Nombre de fichiers WAL non traités | > 1000 |
| Taille totale WAL | Taille totale du WAL en octets | > 10 Go |
| Durée du shift | Temps pour compléter une tâche shift | > 300s |
| Nombre de snapshots | Snapshots Iceberg actifs | > 100 |

### Vérifications de Santé

```bash
# Vérifier la disponibilité du service query
curl http://localhost:3100/ready

# Vérifier la santé du service ingest
curl http://localhost:4318/health
```

## Sauvegarde et Récupération

### Sauvegarde du Catalogue

Nessie stocke les métadonnées du catalogue. Sauvegardez les données RocksDB :

```bash
# Arrêter Nessie
docker stop nessie

# Sauvegarder le répertoire de données
tar -czf nessie-backup.tar.gz /data/nessie

# Redémarrer Nessie
docker start nessie
```

### Récupération des Données

Iceberg supporte les requêtes de voyage dans le temps. Pour récupérer après une suppression accidentelle :

```sql
-- Lister les snapshots disponibles
SELECT * FROM icegate.logs$snapshots;

-- Interroger les données à un snapshot spécifique
SELECT * FROM icegate.logs FOR VERSION AS OF 123456789;

-- Revenir à un snapshot précédent
CALL icegate.system.rollback_to_snapshot('logs', 123456789);
```

### Sauvegarde du Stockage Objet

Activez le versioning sur votre bucket S3 pour la récupération à un point dans le temps :

```bash
aws s3api put-bucket-versioning \
  --bucket icegate-warehouse \
  --versioning-configuration Status=Enabled
```

## Optimisation des Performances

### Performance des Requêtes

- Assurez-vous que les partitions sont correctement élaguées (filtrez sur `tenant_id`, `timestamp`)
- Surveillez le plan de requête avec `/loki/api/v1/explain`
- Augmentez la mémoire du service query pour les agrégations complexes
- Activez le cache du catalogue pour les services query en production

### Performance d'Écriture

- Augmentez le nombre de réplicas du service Ingest pour un débit plus élevé
- Ajustez `queue.write.flush_interval_ms` et `queue.write.max_bytes_per_flush`
- Choisissez le codec de compression approprié (ZSTD pour le meilleur ratio, Snappy pour la vitesse)
- Surveillez la latence d'écriture WAL

### Performance de Compaction

- Augmentez `shift.read.plan_segment_read_parallelism` pour des lectures plus rapides
- Augmentez `shift.jobsmanager.worker_count` pour plus de tâches concurrentes
- Ajustez `shift.jobsmanager.iteration_interval_millisecs` pour des shifts plus fréquents

## Étapes Suivantes

- Mettre en place les procédures de [Dépannage](troubleshooting.md)
- Revoir la configuration de [Déploiement](deployment.md)
- Comprendre le [Modèle de Données](../architecture/data-model.md)

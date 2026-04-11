---
title: Vue d'Ensemble de l'Architecture
description: Architecture système et composants IceGate
---

# Vue d'Ensemble de l'Architecture

IceGate est un moteur de lac de données d'observabilité qui stocke les logs, traces, métriques et événements dans des tables Apache Iceberg avec DataFusion comme moteur de requêtes.

## Principes de Conception

- **Séparation Calcul-Stockage** : Mise à l'échelle indépendante du traitement et du stockage
- **Standards Ouverts** : Construit sur Apache Iceberg, Arrow, Parquet et OpenTelemetry
- **Économique** : L'architecture basée sur le stockage objet minimise les coûts d'infrastructure
- **Transactions ACID** : Support complet des transactions sans base de données OLTP dédiée

## Contexte Système

![Contexte Système](../../assets/c4/structurizr-SystemContext.png)

## Diagramme des Conteneurs

![Conteneurs](../../assets/c4/structurizr-Containers.png)

## Détails des Composants

### Service Ingest

![Composants Ingest](../../assets/c4/structurizr-IngestComponents.png)

**Objectif :** Accepter les données d'observabilité via OpenTelemetry Protocol (OTLP)

- **Protocoles :** OTLP HTTP (port 4318), OTLP gRPC (port 4317)
- **Garantie de Livraison :** Exactly-once
- **Chemin d'Écriture :** Données → WAL (Parquet) → Stockage Objet

Le Write-Ahead Log (WAL) stocke les données sous forme de fichiers Parquet organisés pour la compatibilité avec la couche de stockage Iceberg. Les fichiers WAL peuvent être interrogés directement pour l'accès aux données en temps réel.

### Service Query

![Composants Query](../../assets/c4/structurizr-QueryComponents.png)

**Objectif :** Exécuter des requêtes sur les logs, traces, métriques et événements

- **Moteur :** Apache DataFusion + Apache Arrow
- **APIs :** Loki (3100), Prometheus (9090), Tempo (3200)
- **Langages de Requête :** LogQL, PromQL (planifié), TraceQL (planifié)

Le service query lit depuis les deux sources :

- **WAL** : Pour les données en temps réel (vieilles de quelques secondes)
- **Tables Iceberg** : Pour les données historiques (compactées)

### Service Maintain

![Composants Maintain](../../assets/c4/structurizr-MaintainComponents.png)

**Objectif :** Opérations de cycle de vie et d'optimisation des données

- **Compaction :** Fusion des petits fichiers WAL en tables Iceberg optimisées
- **TTL :** Expiration et suppression des anciennes données
- **Optimisation :** Réécriture des fichiers pour de meilleures performances
- **Nettoyage :** Suppression des fichiers orphelins

### Service Alert (Planifié)

**Objectif :** Alertes basées sur des règles sur les données d'observabilité

- Gestion des règles pour la définition des conditions d'alerte
- Analyse en temps réel utilisant le service Query
- Génération d'événements suivant les conventions sémantiques OpenTelemetry

## Pile Technologique

| Composant | Technologie | Objectif |
|-----------|------------|----------|
| Format de Table | Apache Iceberg 0.9 | Transactions ACID, voyage dans le temps, évolution de schéma |
| Moteur de Requêtes | Apache DataFusion 52.2 | Exécution de requêtes vectorisées |
| Format Mémoire | Apache Arrow 57.0 | Traitement de données sans copie |
| Format de Stockage | Apache Parquet 57.0 | Stockage en colonnes avec compression ZSTD |
| Ingestion | OpenTelemetry 0.31 | Protocole d'observabilité standard (gRPC + HTTP) |
| Catalogue | Nessie, AWS S3 Tables, AWS Glue | Backends de catalogue REST Iceberg |
| Job Manager | icegate-jobmanager | Gestion de l'état des jobs shift basée sur S3 |
| Cache | foyer 0.22 | Cache hybride mémoire + disque pour les lectures S3 |
| Langage | Rust 1.92+ (édition 2024) | Runtime haute performance et sûr en mémoire |

## Flux de Données

### Flux d'Ingestion

1. Le client envoie des données OTLP au service Ingest
2. Ingest valide et transforme les données
3. Les données sont écrites dans le WAL sous forme de fichiers Parquet
4. L'accusé de réception est envoyé au client (exactly-once)

### Flux de Requêtes

1. Le client envoie une requête au service Query
2. La requête est analysée et planifiée par DataFusion
3. Les données sont lues depuis les tables Iceberg et/ou le WAL
4. Les résultats sont formatés et retournés

### Flux de Compaction

1. Le service Maintain surveille la taille du WAL
2. Quand le seuil est atteint, lit les fichiers WAL
3. Fusionne et optimise les données
4. Écrit les nouveaux fichiers de données Iceberg
5. Valide un nouveau snapshot dans le catalogue
6. Supprime les fichiers WAL traités

## Évolutivité

### Mise à l'Échelle Horizontale

- **Ingest :** Augmenter le nombre de réplicas pour un débit plus élevé
- **Query :** Augmenter le nombre de réplicas pour les requêtes concurrentes
- **Maintain :** Instance unique (élection de leader)

### Mise à l'Échelle du Stockage

- Le stockage objet évolue indépendamment
- Pas de limites de capacité (paiement à l'usage)
- Réplication inter-région supportée

## Étapes Suivantes

- En savoir plus sur le [Modèle de Données](data-model.md)
- Explorer les options de [Déploiement](../operations/deployment.md)
- Voir les détails de [Configuration](../getting-started/configuration.md)

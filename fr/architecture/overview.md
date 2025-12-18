---
title: Vue d'Ensemble de l'Architecture
description: Architecture système et composants IceGate
---

# Vue d'Ensemble de l'Architecture

{% note warning %}

Cette page est en cours de traduction. Pour la documentation complète, veuillez consulter la version anglaise.

{% endnote %}

IceGate est un moteur de lac de données d'observabilité qui stocke les logs, traces, métriques et événements dans des tables Apache Iceberg.

## Principes de Conception

- **Séparation Calcul-Stockage** : Mise à l'échelle indépendante du traitement et du stockage
- **Standards Ouverts** : Construit sur Apache Iceberg, Arrow, Parquet et OpenTelemetry
- **Économique** : Architecture basée sur le stockage objet
- **Transactions ACID** : Support complet des transactions

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

### Service Query

![Composants Query](../../assets/c4/structurizr-QueryComponents.png)

**Objectif :** Exécuter des requêtes sur les logs, traces, métriques et événements

- **Moteur :** Apache DataFusion + Apache Arrow
- **APIs :** Loki (3100), Prometheus (9090), Tempo (3200)
- **Langages de Requête :** LogQL, PromQL (planifié), TraceQL (planifié)

### Service Maintain

![Composants Maintain](../../assets/c4/structurizr-MaintainComponents.png)

**Objectif :** Opérations de cycle de vie et d'optimisation des données

- **Compaction :** Fusion des petits fichiers WAL en tables Iceberg optimisées
- **TTL :** Expiration et suppression des anciennes données
- **Optimisation :** Réécriture des fichiers pour de meilleures performances
- **Nettoyage :** Suppression des fichiers orphelins

### Service Alert (Planifié)

**Objectif :** Alertes basées sur des règles sur les données d'observabilité

## Étapes Suivantes

- En savoir plus sur le [Modèle de Données](data-model.md)
- Explorer les options de [Déploiement](../operations/deployment.md)

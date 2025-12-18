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

## Composants Système

- **Ingest** : Réception des données via OTLP
- **Query** : Exécution des requêtes (APIs Loki/Prometheus/Tempo)
- **Maintain** : Opérations de maintenance et compaction
- **Alert** : Alertes basées sur des règles (planifié)

## Étapes Suivantes

- En savoir plus sur le [Modèle de Données](data-model.md)
- Explorer les options de [Déploiement](../operations/deployment.md)

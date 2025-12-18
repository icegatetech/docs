---
title: Modèle de Données
description: Schémas des tables Iceberg IceGate pour les données d'observabilité
---

# Modèle de Données

{% note warning %}

Cette page est en cours de traduction. Pour la documentation complète, veuillez consulter la version anglaise.

{% endnote %}

IceGate stocke les données d'observabilité dans quatre tables Apache Iceberg.

## Vue d'Ensemble des Tables

| Table | Description | Cas d'Usage |
|-------|-------------|-------------|
| `logs` | LogRecords OpenTelemetry | Logs applicatifs |
| `spans` | Spans de traces distribuées | Traçage des requêtes |
| `events` | Événements sémantiques | Événements métier |
| `metrics` | Tous types de métriques | Monitoring de performance |

## Patterns Communs

### Multi-Tenancy

Toutes les tables utilisent le partitionnement par `tenant_id`.

### Stockage des Attributs

Les attributs sont stockés comme `MAP(VARCHAR, VARCHAR)`.

## Étapes Suivantes

- En savoir plus sur l'[Architecture](overview.md)
- Explorer les [Requêtes](../guides/querying.md)

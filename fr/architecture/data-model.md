---
title: Modèle de Données
description: Schémas des tables Iceberg {{product_name}} pour les données d'observabilité
---

# Modèle de Données

{% note warning %}

Cette page est en cours de traduction. Pour la documentation complète, veuillez consulter la version anglaise.

{% endnote %}

{{product_name}} stocke les données d'observabilité dans quatre tables Apache Iceberg.

## Vue d'Ensemble des Tables

| Table | Description | Cas d'Usage |
|-------|-------------|-------------|
| `logs` | LogRecords OpenTelemetry | Logs applicatifs |
| `spans` | Spans de traces distribuées | Traçage des requêtes |
| `events` | Événements sémantiques | Événements métier |
| `metrics` | Tous types de métriques | Monitoring de performance |
| `operations` | Opérations LLM et agents | Usage de tokens, coût, capture des prompts et complétions |
| `prices` | Grille tarifaire LLM globale (sans `tenant_id`) | Attribution des coûts pour `operations` |

## Patterns Communs

### Multi-Tenancy

Toutes les tables utilisent le partitionnement par `tenant_id`.

### Stockage des Attributs

Les attributs sont stockés comme `MAP(VARCHAR, VARCHAR)`.

## Étapes Suivantes

- En savoir plus sur l'[Architecture](overview.md)
- Explorer les [Requêtes](../guides/querying.md)

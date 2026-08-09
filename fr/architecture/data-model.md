---
title: Modèle de Données
description: Schémas des tables Iceberg d'{{product_name}} - tables logs, spans, events, metrics, operations et prices, leurs patterns communs et des exemples de requêtes.
---

# Modèle de Données

{% note warning %}

Cette page est en cours de traduction. Pour la documentation complète, veuillez consulter la version anglaise.

{% endnote %}

{{product_name}} stocke les données d'observabilité dans cinq tables Apache Iceberg par tenant - logs, spans, events, metrics et operations - plus une table de référence globale, prices.

## Vue d'Ensemble des Tables

| Table | Description | Cas d'Usage |
|-------|-------------|-------------|
| `logs` | LogRecords OpenTelemetry | Logs applicatifs |
| `spans` | Spans de traces distribuées | Traçage des requêtes |
| `events` | Événements sémantiques | Événements métier |
| `metrics` | Tous types de métriques | Monitoring de performance |
| `operations` | Opérations LLM et agents | Usage de tokens, coût, capture des prompts et complétions |
| `prices` | Grille tarifaire LLM globale (sans `tenant_id`) | Tarifs de référence pour chiffrer `operations` |

## Patterns Communs

### Multi-Tenancy

Les cinq tables par tenant utilisent le partitionnement par identité sur `tenant_id`. `prices` est une donnée de référence partagée par tous les tenants : elle ne porte pas de `tenant_id` et est partitionnée différemment.

### Stockage des Attributs

Les attributs sont stockés comme `MAP(VARCHAR, VARCHAR)`.

## Étapes Suivantes

- En savoir plus sur l'[Architecture](overview.md)
- Explorer les [Requêtes](../guides/querying.md)

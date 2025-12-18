---
title: Interrogation des Données
description: Interroger les logs, traces et métriques avec LogQL, PromQL et TraceQL
---

# Interrogation des Données

{% note warning %}

Cette page est en cours de traduction. Pour la documentation complète, veuillez consulter la version anglaise.

{% endnote %}

IceGate fournit des APIs compatibles Loki, Prometheus et Tempo pour interroger les données d'observabilité.

## LogQL pour les Logs

LogQL est le langage de requête pour les logs, compatible avec Grafana Loki.

### Sélecteur de Flux de Logs

```logql
# Sélectionner par nom de service
{service_name="api-service"}

# Labels multiples
{service_name="api-service", severity_text="ERROR"}
```

### Filtres de Lignes

```logql
# Contient
{service_name="api-service"} |= "erreur"

# Ne contient pas
{service_name="api-service"} != "debug"
```

### Requêtes Métriques

```logql
# Compter les logs dans le temps
count_over_time({service_name="api-service"}[5m])

# Taux de logs par seconde
rate({service_name="api-service"}[1m])
```

## Étapes Suivantes

- Explorez la [Référence API Loki](../api-reference/loki.md)
- Configurez le [Multi-Tenancy](multi-tenancy.md)

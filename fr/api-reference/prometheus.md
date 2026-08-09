---
title: Référence API Prometheus
description: API compatible Prometheus prévue — pas encore implémentée
---

# Référence API Prometheus

{% note warning %}

Cette page est en cours de traduction. Pour la documentation complète, veuillez consulter la version anglaise.

{% endnote %}

{% note warning %}

**Pas encore implémentée.** Les routes ci-dessous sont montées sur le port 9090, mais chacune
d'elles renvoie `501 Not Implemented` ; seul `/-/ready` répond. Cette page documente la surface
*prévue* afin que les intégrateurs voient la direction prise — ne développez pas encore dessus.

Pour interroger les métriques aujourd'hui, utilisez
[Arrow Flight SQL](../guides/querying.md) sur les mêmes données.

{% endnote %}

Voici la forme prévue de l'API HTTP compatible Prometheus® d'{{product_name}} pour interroger les métriques.
Voir [Marques](../trademarks.md) pour l'attribution.

## URL de Base

```
http://localhost:9090
```

## État de l'Implémentation

Aucun de ces points de terminaison n'est implémenté : ils renvoient tous `501 Not Implemented`. Seul `/-/ready` répond.

## Étapes Suivantes

- En savoir plus sur l'[Ingestion de Données](../guides/ingestion.md)
- Explorez l'[API Loki](loki.md)

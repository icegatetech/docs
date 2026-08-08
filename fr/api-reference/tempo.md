---
title: Référence API Tempo
description: Points de terminaison HTTP de l'API compatible Tempo servis par {{product_name}}
---

# Référence API Tempo

{% note warning %}

Cette page est en cours de traduction. Pour la documentation complète, veuillez consulter la version anglaise.

{% endnote %}

{{product_name}} fournit une API HTTP compatible Tempo® pour interroger les traces distribuées, servie sur le
port 3200. Les points de terminaison documentés ci-dessous sont ceux implémentés — il s'agit d'un
sous-ensemble de l'API de Tempo, et non d'une réimplémentation complète : tout ce qui n'y figure pas
doit être considéré comme non implémenté. TraceQL est pris en charge pour `/api/search` ; les
fonctionnalités TraceQL non encore implémentées renvoient `501 Not Implemented` plutôt que des
résultats erronés. Voir [Marques](../trademarks.md) pour l'attribution.

## URL de Base

```
http://localhost:3200
```

## État de l'Implémentation

L'API Tempo est actuellement en développement.

## Étapes Suivantes

- En savoir plus sur l'[Ingestion de Données](../guides/ingestion.md)
- Explorez l'[API Loki](loki.md)

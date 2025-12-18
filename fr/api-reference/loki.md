---
title: Référence API Loki
description: Points de terminaison HTTP de l'API compatible Loki
---

# Référence API Loki

{% note warning %}

Cette page est en cours de traduction. Pour la documentation complète, veuillez consulter la version anglaise.

{% endnote %}

IceGate fournit une API HTTP compatible Loki pour interroger les logs.

## URL de Base

```
http://localhost:3100
```

## Authentification

Toutes les requêtes nécessitent l'en-tête `X-Scope-OrgID` pour l'identification du tenant.

## Points de Terminaison

### Query Range

`GET /loki/api/v1/query_range`

### Labels

`GET /loki/api/v1/labels`

### Label Values

`GET /loki/api/v1/label/{name}/values`

### Series

`GET /loki/api/v1/series`

## Étapes Suivantes

- Apprenez le [Requêtage LogQL](../guides/querying.md)
- Explorez l'[API Prometheus](prometheus.md)

---
title: Référence API Loki
description: Points de terminaison HTTP de l'API compatible Loki
---

# Référence API Loki

IceGate fournit une API HTTP compatible Loki pour interroger les logs.

## URL de Base

```
http://localhost:3100
```

## Authentification

Toutes les requêtes nécessitent l'en-tête `X-Scope-OrgID` pour l'identification du tenant.

## Points de Terminaison

### Instant Query

Interroger les logs ou métriques à un instant donné.

**Point de terminaison :** `GET /loki/api/v1/query` ou `POST /loki/api/v1/query`

**Paramètres :**

| Paramètre | Type | Requis | Description |
|-----------|------|--------|-------------|
| `query` | string | Oui | Requête LogQL |
| `time` | int | Non | Timestamp d'évaluation (secondes ou nanosecondes Unix). Défaut : heure actuelle |
| `limit` | int | Non | Nombre maximum d'entrées (défaut : 100) |
| `direction` | string | Non | `forward` ou `backward` (défaut : backward) |

**Exemple :**

```bash
curl -G http://localhost:3100/loki/api/v1/query \
  --data-urlencode 'query=count_over_time({service_name="api-service"}[5m])' \
  -H "X-Scope-OrgID: my-tenant"
```

### Query Range

Interroger les logs ou métriques sur un intervalle de temps.

**Point de terminaison :** `GET /loki/api/v1/query_range`

**Paramètres :**

| Paramètre | Type | Requis | Description |
|-----------|------|--------|-------------|
| `query` | string | Oui | Requête LogQL |
| `start` | int | Oui | Timestamp de début (secondes ou nanosecondes Unix) |
| `end` | int | Oui | Timestamp de fin (secondes ou nanosecondes Unix) |
| `limit` | int | Non | Nombre maximum d'entrées (défaut : 100) |
| `step` | duration | Non | Pas de résolution de la requête (ex. "5m") |
| `direction` | string | Non | `forward` ou `backward` (défaut : backward) |

**Exemple :**

```bash
curl -G http://localhost:3100/loki/api/v1/query_range \
  --data-urlencode 'query={service_name="api-service"}' \
  --data-urlencode 'start=1704067200' \
  --data-urlencode 'end=1704153600' \
  --data-urlencode 'limit=1000' \
  -H "X-Scope-OrgID: my-tenant"
```

**Réponse (Requête Log) :**

```json
{
  "status": "success",
  "data": {
    "resultType": "streams",
    "result": [
      {
        "stream": {
          "service_name": "api-service",
          "severity_text": "INFO"
        },
        "values": [
          ["1704067200000000000", "Request processed successfully"]
        ]
      }
    ]
  }
}
```

**Réponse (Requête Métrique) :**

```json
{
  "status": "success",
  "data": {
    "resultType": "matrix",
    "result": [
      {
        "metric": {
          "service_name": "api-service"
        },
        "values": [
          [1704067200, "42"],
          [1704067500, "38"]
        ]
      }
    ]
  }
}
```

### Labels

Obtenir tous les noms de labels.

**Point de terminaison :** `GET /loki/api/v1/labels`

**Paramètres :**

| Paramètre | Type | Requis | Description |
|-----------|------|--------|-------------|
| `start` | int | Non | Timestamp de début |
| `end` | int | Non | Timestamp de fin |

**Exemple :**

```bash
curl http://localhost:3100/loki/api/v1/labels \
  -H "X-Scope-OrgID: my-tenant"
```

**Réponse :**

```json
{
  "status": "success",
  "data": [
    "service_name",
    "severity_text",
    "trace_id"
  ]
}
```

### Label Values

Obtenir les valeurs d'un label spécifique.

**Point de terminaison :** `GET /loki/api/v1/label/{name}/values`

**Paramètres :**

| Paramètre | Type | Requis | Description |
|-----------|------|--------|-------------|
| `start` | int | Non | Timestamp de début |
| `end` | int | Non | Timestamp de fin |

**Exemple :**

```bash
curl http://localhost:3100/loki/api/v1/label/service_name/values \
  -H "X-Scope-OrgID: my-tenant"
```

**Réponse :**

```json
{
  "status": "success",
  "data": [
    "api-service",
    "worker-service",
    "gateway"
  ]
}
```

### Series

Obtenir les ensembles de labels correspondant aux sélecteurs.

**Point de terminaison :** `GET /loki/api/v1/series`

**Paramètres :**

| Paramètre | Type | Requis | Description |
|-----------|------|--------|-------------|
| `match[]` | string | Oui | Sélecteur(s) de flux de logs |
| `start` | int | Non | Timestamp de début |
| `end` | int | Non | Timestamp de fin |

**Exemple :**

```bash
curl -G http://localhost:3100/loki/api/v1/series \
  --data-urlencode 'match[]={service_name=~"api-.*"}' \
  -H "X-Scope-OrgID: my-tenant"
```

**Réponse :**

```json
{
  "status": "success",
  "data": [
    {"service_name": "api-service", "severity_text": "INFO"},
    {"service_name": "api-gateway", "severity_text": "ERROR"}
  ]
}
```

### Explain

Obtenir le plan d'exécution d'une requête (extension IceGate).

**Point de terminaison :** `GET /loki/api/v1/explain`

**Paramètres :**

| Paramètre | Type | Requis | Description |
|-----------|------|--------|-------------|
| `query` | string | Oui | Requête LogQL |

**Exemple :**

```bash
curl -G http://localhost:3100/loki/api/v1/explain \
  --data-urlencode 'query=count_over_time({service_name="api-service"}[5m])' \
  -H "X-Scope-OrgID: my-tenant"
```

### Health Check

**Point de terminaison :** `GET /ready`

**Réponse :**

```json
{"status": "ready"}
```

## Réponses d'Erreur

Toutes les erreurs retournent une réponse JSON :

```json
{
  "status": "error",
  "errorType": "bad_data",
  "error": "invalid query syntax"
}
```

| Type d'Erreur | Code HTTP | Description |
|---------------|-----------|-------------|
| `bad_data` | 400 | Requête ou syntaxe invalide |
| `not_implemented` | 501 | Fonctionnalité non implémentée |
| `internal` | 500 | Erreur interne du serveur |

## Étapes Suivantes

- Apprenez le [Requêtage LogQL](../guides/querying.md)
- Explorez l'[API Prometheus](prometheus.md)
- Voir l'[API Tempo](tempo.md) pour les traces

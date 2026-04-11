---
title: Guide de Démarrage
description: Ingérer et interroger vos premières données d'observabilité avec IceGate
---

# Guide de Démarrage

Ce guide vous accompagne dans l'ingestion de logs, traces et métriques dans IceGate, ainsi que dans leur interrogation via l'API et Grafana.

{% note info %}

Ce guide suppose qu'IceGate est déjà en cours d'exécution. Consultez [Installation](installation.md) pour le déploiement Helm ou [Environnement de développement](../development/setup.md) pour un environnement local.

{% endnote %}

## Ingérer des Logs

IceGate accepte les données via le protocole OpenTelemetry (OTLP) sur le service d'ingestion.

### Envoyer des Logs via OTLP HTTP

```bash
curl -X POST http://localhost:4318/v1/logs \
  -H "Content-Type: application/json" \
  -H "X-Scope-OrgID: demo" \
  -d '{
    "resourceLogs": [{
      "resource": {
        "attributes": [
          {"key": "service.name", "value": {"stringValue": "my-service"}}
        ]
      },
      "scopeLogs": [{
        "logRecords": [{
          "timeUnixNano": "'$(date +%s)000000000'",
          "body": {"stringValue": "User login successful"},
          "severityText": "INFO",
          "severityNumber": 9,
          "attributes": [
            {"key": "user.id", "value": {"stringValue": "user-42"}},
            {"key": "http.method", "value": {"stringValue": "POST"}}
          ]
        }]
      }]
    }]
  }'
```

### Envoyer des Logs via OTLP gRPC

Utilisez n'importe quel SDK OpenTelemetry. Exemple avec Python :

```python
from opentelemetry.sdk._logs import LoggerProvider
from opentelemetry.sdk._logs.export import BatchLogRecordProcessor
from opentelemetry.exporter.otlp.proto.grpc._log_exporter import OTLPLogExporter

provider = LoggerProvider()
provider.add_log_record_processor(
    BatchLogRecordProcessor(
        OTLPLogExporter(
            endpoint="localhost:4317",
            headers={"X-Scope-OrgID": "demo"},
            insecure=True,
        )
    )
)
```

## Ingérer des Traces

Envoyez des spans de traces distribuées :

```bash
curl -X POST http://localhost:4318/v1/traces \
  -H "Content-Type: application/json" \
  -H "X-Scope-OrgID: demo" \
  -d '{
    "resourceSpans": [{
      "resource": {
        "attributes": [
          {"key": "service.name", "value": {"stringValue": "my-service"}}
        ]
      },
      "scopeSpans": [{
        "spans": [{
          "traceId": "5B8EFFF798038103D269B633813FC60C",
          "spanId": "EEE19B7EC3C1B174",
          "name": "GET /api/users",
          "kind": 2,
          "startTimeUnixNano": "'$(date +%s)000000000'",
          "endTimeUnixNano": "'$(date +%s)100000000'",
          "status": {"code": 1},
          "attributes": [
            {"key": "http.method", "value": {"stringValue": "GET"}},
            {"key": "http.status_code", "value": {"intValue": "200"}}
          ]
        }]
      }]
    }]
  }'
```

## Ingérer des Métriques

Envoyez des données de métriques :

```bash
curl -X POST http://localhost:4318/v1/metrics \
  -H "Content-Type: application/json" \
  -H "X-Scope-OrgID: demo" \
  -d '{
    "resourceMetrics": [{
      "resource": {
        "attributes": [
          {"key": "service.name", "value": {"stringValue": "my-service"}}
        ]
      },
      "scopeMetrics": [{
        "metrics": [{
          "name": "http_requests_total",
          "sum": {
            "dataPoints": [{
              "startTimeUnixNano": "'$(date +%s)000000000'",
              "timeUnixNano": "'$(date +%s)000000000'",
              "asInt": "42",
              "attributes": [
                {"key": "method", "value": {"stringValue": "GET"}},
                {"key": "status", "value": {"stringValue": "200"}}
              ]
            }],
            "aggregationTemporality": 2,
            "isMonotonic": true
          }
        }]
      }]
    }]
  }'
```

## Interroger les Logs avec LogQL

IceGate fournit une API compatible Loki sur le service de requête (port 3100).

### Requête de Logs Basique

```bash
curl -G http://localhost:3100/loki/api/v1/query_range \
  --data-urlencode 'query={service_name="my-service"}' \
  --data-urlencode 'start='$(date -v-1H +%s) \
  --data-urlencode 'end='$(date +%s) \
  --data-urlencode 'limit=100' \
  -H "X-Scope-OrgID: demo"
```

### Filtrer par Sévérité

```bash
curl -G http://localhost:3100/loki/api/v1/query_range \
  --data-urlencode 'query={service_name="my-service", severity_text="ERROR"}' \
  --data-urlencode 'start='$(date -v-1H +%s) \
  --data-urlencode 'end='$(date +%s) \
  -H "X-Scope-OrgID: demo"
```

### Rechercher dans le Contenu des Logs

```bash
curl -G http://localhost:3100/loki/api/v1/query_range \
  --data-urlencode 'query={service_name="my-service"} |= "login"' \
  --data-urlencode 'start='$(date -v-1H +%s) \
  --data-urlencode 'end='$(date +%s) \
  -H "X-Scope-OrgID: demo"
```

### Agréger les Logs en Métriques

```bash
# Compter les logs par fenêtre de 5 minutes
curl -G http://localhost:3100/loki/api/v1/query_range \
  --data-urlencode 'query=count_over_time({service_name="my-service"}[5m])' \
  --data-urlencode 'start='$(date -v-1H +%s) \
  --data-urlencode 'end='$(date +%s) \
  --data-urlencode 'step=300' \
  -H "X-Scope-OrgID: demo"

# Taux d'erreurs par seconde
curl -G http://localhost:3100/loki/api/v1/query_range \
  --data-urlencode 'query=rate({severity_text="ERROR"}[1m])' \
  --data-urlencode 'start='$(date -v-1H +%s) \
  --data-urlencode 'end='$(date +%s) \
  --data-urlencode 'step=60' \
  -H "X-Scope-OrgID: demo"
```

## Explorer les Labels et les Séries

### Lister Tous les Labels

```bash
curl http://localhost:3100/loki/api/v1/labels \
  -H "X-Scope-OrgID: demo"
```

### Obtenir les Valeurs d'un Label

```bash
curl http://localhost:3100/loki/api/v1/label/service_name/values \
  -H "X-Scope-OrgID: demo"
```

### Trouver les Séries Correspondantes

```bash
curl -G http://localhost:3100/loki/api/v1/series \
  --data-urlencode 'match[]={service_name=~"my-.*"}' \
  -H "X-Scope-OrgID: demo"
```

## Utiliser Grafana

IceGate est compatible avec la source de données Loki de Grafana pour la visualisation et la création de tableaux de bord.

### Ajouter IceGate comme Source de Données

1. Ouvrez Grafana (par défaut : [http://localhost:3000](http://localhost:3000))
2. Allez dans **Connections** > **Data sources** > **Add data source**
3. Sélectionnez **Loki**
4. Définissez l'URL à `http://icegate-query:3100` (ou `http://localhost:3100` pour un accès local)
5. Sous **HTTP Headers**, ajoutez :
   - Header : `X-Scope-OrgID`
   - Value : `demo`
6. Cliquez sur **Save & Test**

### Explorer les Logs

1. Allez dans **Explore**
1. Sélectionnez la source de données **Loki**
1. Entrez une requête LogQL : `{service_name="my-service"}`
1. Cliquez sur **Run query**
1. Basculez entre les vues **Logs** et **Graph**

### Créer un Tableau de Bord

1. Allez dans **Dashboards** > **New** > **New Dashboard**
2. Ajoutez un **panneau Logs** :
   - Query : `{service_name="my-service"}`
   - Visualisation : Logs
3. Ajoutez un **panneau Time series** pour le taux d'erreurs :
   - Query : `sum by (service_name) (rate({severity_text="ERROR"}[5m]))`
   - Visualisation : Time series
4. Ajoutez un **panneau Stat** pour le volume de logs :
   - Query : `sum(count_over_time({service_name="my-service"}[1h]))`
   - Visualisation : Stat

### Tableaux de Bord Préconfigurés

Si déployé avec les overlays Kustomize ou Docker Compose, Grafana est préconfiguré avec des tableaux de bord IceGate pour les métriques des services d'ingestion et de requête.

## Utiliser l'OpenTelemetry Collector

Pour les charges de travail de production, utilisez l'[OpenTelemetry Collector](https://opentelemetry.io/docs/collector/) pour transférer les données de vos applications vers IceGate :

```yaml
# otel-collector-config.yaml
exporters:
  otlp/icegate:
    endpoint: icegate-ingest:4317
    tls:
      insecure: true
    headers:
      X-Scope-OrgID: my-tenant

service:
  pipelines:
    logs:
      receivers: [otlp]
      exporters: [otlp/icegate]
    traces:
      receivers: [otlp]
      exporters: [otlp/icegate]
    metrics:
      receivers: [otlp]
      exporters: [otlp/icegate]
```

## Multi-Tenancy

IceGate isole les données par tenant à l'aide de l'en-tête `X-Scope-OrgID`. Les données de chaque tenant sont physiquement partitionnées.

```bash
# Ingestion pour le tenant "team-a"
curl -X POST http://localhost:4318/v1/logs \
  -H "X-Scope-OrgID: team-a" \
  -H "Content-Type: application/json" \
  -d '...'

# La requête ne voit que les données de team-a
curl -G http://localhost:3100/loki/api/v1/query_range \
  --data-urlencode 'query={service_name="api"}' \
  -H "X-Scope-OrgID: team-a"
```

Consultez [Multi-Tenancy](../guides/multi-tenancy.md) pour plus de détails.

## Étapes Suivantes

- Apprenez les [requêtes LogQL](../guides/querying.md) en profondeur
- Explorez la référence de l'[API Loki](../api-reference/loki.md)
- Configurez les pipelines d'[ingestion de données](../guides/ingestion.md)
- Comprenez le [modèle de données](../architecture/data-model.md)

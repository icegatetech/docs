---
title: API d'Ingestion OTLP
description: Points d'accès OpenTelemetry Protocol pour l'ingestion de données
---

# API d'Ingestion OTLP

IceGate accepte les données d'observabilité via le protocole OpenTelemetry (OTLP). Les transports HTTP et gRPC sont pris en charge.

## Protocoles

| Protocole | Port par défaut | Types de contenu |
|-----------|----------------|------------------|
| HTTP | 4318 | `application/x-protobuf`, `application/json` |
| gRPC | 4317 | Protobuf (gRPC standard) |

## Authentification

Toutes les requêtes nécessitent l'en-tête `X-Scope-OrgID` (insensible à la casse) pour l'identification du locataire :

```
X-Scope-OrgID: my-tenant
```

**Règles pour l'identifiant du locataire :**

- Caractères autorisés : alphanumériques ASCII, tirets (`-`), underscores (`_`)
- Valeur par défaut : `default` (lorsque l'en-tête est absent ou invalide)

## Points d'accès HTTP

### Ingestion de logs

**Point d'accès :** `POST /v1/logs`

Ingestion d'enregistrements de logs OpenTelemetry.

**En-têtes :**

| En-tête | Requis | Description |
|---------|--------|-------------|
| `Content-Type` | Non | `application/x-protobuf` (par défaut) ou `application/json` |
| `X-Scope-OrgID` | Non | Identifiant du locataire (par défaut : `default`) |

**Exemple (JSON) :**

```bash
curl -X POST http://localhost:4318/v1/logs \
  -H "Content-Type: application/json" \
  -H "X-Scope-OrgID: my-tenant" \
  -d '{
    "resourceLogs": [{
      "resource": {
        "attributes": [
          {"key": "service.name", "value": {"stringValue": "api-service"}}
        ]
      },
      "scopeLogs": [{
        "logRecords": [{
          "timeUnixNano": "1704067200000000000",
          "body": {"stringValue": "Request processed successfully"},
          "severityText": "INFO",
          "severityNumber": 9,
          "attributes": [
            {"key": "http.method", "value": {"stringValue": "GET"}},
            {"key": "http.status_code", "value": {"intValue": "200"}}
          ]
        }]
      }]
    }]
  }'
```

**Exemple (Protobuf) :**

```bash
# Utilisation d'un SDK ou collecteur OpenTelemetry avec encodage protobuf
curl -X POST http://localhost:4318/v1/logs \
  -H "Content-Type: application/x-protobuf" \
  -H "X-Scope-OrgID: my-tenant" \
  --data-binary @logs.pb
```

**Réponse (200 OK) :**

```json
{
  "partialSuccess": {
    "rejectedLogRecords": 0,
    "errorMessage": ""
  }
}
```

### Ingestion de traces

**Point d'accès :** `POST /v1/traces`

Ingestion de spans de traces OpenTelemetry.

```bash
curl -X POST http://localhost:4318/v1/traces \
  -H "Content-Type: application/json" \
  -H "X-Scope-OrgID: my-tenant" \
  -d '{
    "resourceSpans": [{
      "resource": {
        "attributes": [
          {"key": "service.name", "value": {"stringValue": "api-service"}}
        ]
      },
      "scopeSpans": [{
        "spans": [{
          "traceId": "5B8EFFF798038103D269B633813FC60C",
          "spanId": "EEE19B7EC3C1B174",
          "name": "GET /api/users",
          "kind": 2,
          "startTimeUnixNano": "1704067200000000000",
          "endTimeUnixNano": "1704067200100000000",
          "status": {"code": 1}
        }]
      }]
    }]
  }'
```

### Ingestion de métriques

**Point d'accès :** `POST /v1/metrics`

Ingestion de métriques OpenTelemetry.

```bash
curl -X POST http://localhost:4318/v1/metrics \
  -H "Content-Type: application/json" \
  -H "X-Scope-OrgID: my-tenant" \
  -d '{
    "resourceMetrics": [{
      "resource": {
        "attributes": [
          {"key": "service.name", "value": {"stringValue": "api-service"}}
        ]
      },
      "scopeMetrics": [{
        "metrics": [{
          "name": "http_requests_total",
          "sum": {
            "dataPoints": [{
              "startTimeUnixNano": "1704067200000000000",
              "timeUnixNano": "1704067260000000000",
              "asInt": "1234"
            }],
            "aggregationTemporality": 2,
            "isMonotonic": true
          }
        }]
      }]
    }]
  }'
```

### Vérification de l'état de santé

**Point d'accès :** `GET /health`

```bash
curl http://localhost:4318/health
```

**Réponse :**

```json
{"status": "healthy"}
```

## Services gRPC

Le serveur gRPC implémente les services standard du collecteur OpenTelemetry sur le port 4317.

### Services

| Service | Méthode | Description |
|---------|---------|-------------|
| `opentelemetry.proto.collector.logs.v1.LogsService` | `Export` | Ingestion d'enregistrements de logs |
| `opentelemetry.proto.collector.trace.v1.TraceService` | `Export` | Ingestion de spans de traces |
| `opentelemetry.proto.collector.metrics.v1.MetricsService` | `Export` | Ingestion de métriques |

### Métadonnées du locataire

Transmettez l'identifiant du locataire en tant que métadonnée gRPC :

```
x-scope-orgid: my-tenant
```

### Exemple avec grpcurl

```bash
# Lister les services disponibles
grpcurl -plaintext localhost:4317 list

# Envoyer des logs (nécessite un fichier proto)
grpcurl -plaintext \
  -H "x-scope-orgid: my-tenant" \
  -d '{"resourceLogs": [...]}' \
  localhost:4317 \
  opentelemetry.proto.collector.logs.v1.LogsService/Export
```

## Utilisation des SDK OpenTelemetry

### Python

```python
from opentelemetry.sdk._logs import LoggerProvider
from opentelemetry.sdk._logs.export import BatchLogRecordProcessor
from opentelemetry.exporter.otlp.proto.grpc._log_exporter import OTLPLogExporter

provider = LoggerProvider()
provider.add_log_record_processor(
    BatchLogRecordProcessor(
        OTLPLogExporter(
            endpoint="localhost:4317",
            headers={"X-Scope-OrgID": "my-tenant"},
            insecure=True,
        )
    )
)
```

### Go

```go
import "go.opentelemetry.io/otel/exporters/otlp/otlplog/otlploggrpc"

exporter, _ := otlploggrpc.New(ctx,
    otlploggrpc.WithEndpoint("localhost:4317"),
    otlploggrpc.WithInsecure(),
    otlploggrpc.WithHeaders(map[string]string{
        "X-Scope-OrgID": "my-tenant",
    }),
)
```

### Collecteur OpenTelemetry

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

## Réponses d'erreur

### Erreurs HTTP

| Code HTTP | Type d'erreur | Description |
|-----------|--------------|-------------|
| 400 | Bad Request | Charge utile OTLP ou encodage invalide |
| 408 | Request Timeout | Requête annulée |
| 500 | Internal Server Error | Échec du stockage ou du traitement |
| 501 | Not Implemented | Point d'accès pas encore implémenté |
| 503 | Service Unavailable | File d'attente WAL pleine ou stockage inaccessible |

### Codes d'état gRPC

| Code gRPC | Description |
|-----------|-------------|
| `INVALID_ARGUMENT` | Charge utile ou encodage invalide |
| `UNIMPLEMENTED` | Service pas encore implémenté |
| `INTERNAL` | Échec du stockage ou du traitement |
| `CANCELLED` | Requête annulée |
| `UNAVAILABLE` | File d'attente WAL pleine ou stockage inaccessible |

## Tests de charge avec IceGen

[IceGen](https://github.com/icegatetech/icegen) est un générateur de logs OpenTelemetry haute performance pour tester l'ingestion d'IceGate.

### Installation

```bash
git clone https://github.com/icegatetech/icegen.git
cd icegen
cargo build --release
```

### Utilisation

```bash
# Envoyer 100 logs via HTTP JSON
otel-log-generator otel \
  --endpoint http://localhost:4318/v1/logs \
  --count 100

# Envoyer via gRPC avec 8 locataires et 20 workers simultanés
otel-log-generator otel \
  --endpoint http://localhost:4317 \
  --transport grpc \
  --tenant-count 8 \
  --count 1000 \
  --concurrency 20

# Mode continu avec encodage protobuf
otel-log-generator otel \
  --endpoint http://localhost:4318/v1/logs \
  --use-protobuf \
  --continuous \
  --message-interval-ms 100 \
  --concurrency 10

# Messages agrégés (5 enregistrements par requête)
otel-log-generator otel \
  --endpoint http://localhost:4318/v1/logs \
  --records-per-message 5 \
  --count 100

# Tester la gestion des erreurs avec 10% d'enregistrements invalides
otel-log-generator otel \
  --endpoint http://localhost:4318/v1/logs \
  --invalid-record-percent 10.0 \
  --count 100
```

### Paramètres d'IceGen

| Paramètre | Par défaut | Description |
|-----------|-----------|-------------|
| `--endpoint` | — | URL du point d'accès OTLP |
| `--transport` | `http` | Transport : `http` ou `grpc` |
| `--use-protobuf` | `false` | Utiliser l'encodage protobuf (HTTP uniquement) |
| `--count` | `1` | Nombre de messages à envoyer |
| `--concurrency` | `1` | Nombre de workers simultanés |
| `--message-interval-ms` | `0` | Délai entre les messages (ms) |
| `--records-per-message` | `1` | Enregistrements de logs par message |
| `--continuous` | `false` | Exécution en continu |
| `--tenant-id` | `default` | Identifiant du locataire |
| `--tenant-count` | `1` | Nombre de locataires aléatoires |
| `--invalid-record-percent` | `0.0` | Pourcentage d'enregistrements invalides |

## Flux de données

1. Le client envoie des données OTLP au service d'ingestion (Ingest)
2. Ingest valide et transforme les données en Arrow RecordBatch
3. Les enregistrements sont triés en groupes de lignes WAL par clés de partition
4. Les données sont écrites dans le WAL (Parquet sur le stockage objet) via une file d'attente bornée
5. Un accusé de réception est envoyé au client (livraison exactement une fois)
6. Le processus Shift compacte le WAL en tables Iceberg de manière asynchrone

## Étapes suivantes

- Interroger les données ingérées avec l'[API Loki](loki.md)
- En savoir plus sur le [modèle de données](../architecture/data-model.md)
- Configurer les pipelines d'[ingestion](../guides/ingestion.md)

---
title: Guide de Démarrage Rapide
description: Commencez avec IceGate en 5 minutes
---

# Guide de Démarrage Rapide

Ce guide vous accompagne dans l'ingestion de vos premiers logs et leur interrogation avec IceGate.

## Démarrer l'Environnement de Développement

Démarrez la stack complète IceGate avec Docker Compose :

```bash
make dev
```

Cela démarre les services suivants :

| Service | Port | Description |
|---------|------|-------------|
| MinIO (S3) | 9000, 9001 | Stockage objet backend |
| Nessie | 19120 | Catalogue Iceberg |
| Service Query | 3100 | API compatible Loki |
| Grafana | 3000 | Tableau de bord d'observabilité |
| Trino | 8080 | Moteur de requêtes SQL |

## Vérifier que les Services Fonctionnent

Vérifiez que tous les services sont en bonne santé :

```bash
# Vérifier l'API Loki
curl http://localhost:3100/ready

# Vérifier Grafana
curl http://localhost:3000/api/health
```

## Envoyer des Logs de Test

IceGate accepte les logs via le protocole OpenTelemetry (OTLP).

### Avec curl (OTLP HTTP)

```bash
curl -X POST http://localhost:4318/v1/logs \
  -H "Content-Type: application/json" \
  -H "X-Scope-OrgID: demo" \
  -d '{
    "resourceLogs": [{
      "resource": {
        "attributes": [
          {"key": "service.name", "value": {"stringValue": "mon-service"}}
        ]
      },
      "scopeLogs": [{
        "logRecords": [{
          "timeUnixNano": "'$(date +%s)000000000'",
          "body": {"stringValue": "Bonjour depuis IceGate!"},
          "severityText": "INFO"
        }]
      }]
    }]
  }'
```

## Interroger les Logs

### Avec l'API Loki

Interrogez les logs avec l'API compatible Loki :

```bash
curl -G http://localhost:3100/loki/api/v1/query_range \
  --data-urlencode 'query={service_name="mon-service"}' \
  --data-urlencode 'start='$(date -v-1H +%s) \
  --data-urlencode 'end='$(date +%s) \
  -H "X-Scope-OrgID: demo"
```

### Avec Grafana

1. Ouvrez Grafana à [http://localhost:3000](http://localhost:3000)
2. Naviguez vers Explore
3. Sélectionnez la source de données Loki
4. Entrez une requête LogQL : `{service_name="mon-service"}`
5. Cliquez sur "Run query"

## Requêtes avec LogQL

IceGate supporte LogQL pour interroger les logs :

```logql
# Filtrer par service
{service_name="mon-service"}

# Filtrer avec contenu de ligne
{service_name="mon-service"} |= "erreur"

# Compter les logs dans le temps
count_over_time({service_name="mon-service"}[5m])

# Taux de logs
rate({service_name="mon-service"}[1m])
```

## Étapes Suivantes

- En savoir plus sur la [Configuration](configuration.md)
- Explorer l'[Ingestion de Données](../guides/ingestion.md) en détail
- Comprendre les capacités de [Requêtes](../guides/querying.md)

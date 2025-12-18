---
title: Ingestion de Données
description: Ingérer des logs, traces et métriques dans IceGate
---

# Ingestion de Données

{% note warning %}

Cette page est en cours de traduction. Pour la documentation complète, veuillez consulter la version anglaise.

{% endnote %}

IceGate accepte les données d'observabilité via le protocole OpenTelemetry (OTLP).

## Protocoles Supportés

| Protocole | Port | Description |
|-----------|------|-------------|
| OTLP HTTP | 4318 | HTTP/JSON ou HTTP/Protobuf |
| OTLP gRPC | 4317 | gRPC/Protobuf |

## Identification du Tenant

IceGate est multi-tenant. Spécifiez le tenant avec l'en-tête `X-Scope-OrgID` :

```bash
curl -X POST http://localhost:4318/v1/logs \
  -H "X-Scope-OrgID: tenant-123" \
  -H "Content-Type: application/json" \
  -d '...'
```

## Étapes Suivantes

- Apprenez à [Interroger les Données](querying.md)
- Configurez le [Multi-Tenancy](multi-tenancy.md)

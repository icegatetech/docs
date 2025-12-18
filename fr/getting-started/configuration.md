---
title: Configuration
description: Configurer les composants IceGate
---

# Configuration

{% note warning %}

Cette page est en cours de traduction. Pour la documentation complète, veuillez consulter la version anglaise.

{% endnote %}

IceGate utilise des fichiers de configuration YAML pour configurer ses composants.

## Structure du Fichier de Configuration

### Configuration du Service Query

```yaml
# query.yaml
loki:
  enabled: true
  host: "0.0.0.0"
  port: 3100

prometheus:
  enabled: true
  host: "0.0.0.0"
  port: 9090

tempo:
  enabled: true
  host: "0.0.0.0"
  port: 3200
```

## Variables d'Environnement

| Variable | Description | Défaut |
|----------|-------------|--------|
| `AWS_ACCESS_KEY_ID` | Clé d'accès S3 | - |
| `AWS_SECRET_ACCESS_KEY` | Clé secrète S3 | - |
| `AWS_REGION` | Région S3 | `us-east-1` |

## Étapes Suivantes

- En savoir plus sur l'[Ingestion de Données](../guides/ingestion.md)
- Explorer les capacités de [Requêtes](../guides/querying.md)

---
title: Interrogation des Données
description: Interroger les logs, traces et métriques avec LogQL, PromQL et TraceQL
---

# Interrogation des Données

IceGate fournit des APIs compatibles Loki, Prometheus et Tempo pour interroger les données d'observabilité.

## LogQL pour les Logs

LogQL est le langage de requête pour les logs, compatible avec Grafana Loki.

### Sélecteur de Flux de Logs

Sélectionner les logs par labels :

```logql
# Sélectionner par nom de service
{service_name="api-service"}

# Labels multiples
{service_name="api-service", severity_text="ERROR"}

# Correspondance regex de labels
{service_name=~"api-.*"}

# Correspondance négative
{service_name!="internal-service"}
```

### Filtres de Lignes

Filtrer les lignes de log par contenu :

```logql
# Contient
{service_name="api-service"} |= "error"

# Ne contient pas
{service_name="api-service"} != "debug"

# Correspondance regex
{service_name="api-service"} |~ "status=[45][0-9][0-9]"

# Regex non correspondant
{service_name="api-service"} !~ "health"
```

### Filtres de Labels

Filtrer par valeurs de labels :

```logql
# Comparaison numérique
{service_name="api-service"} | severity_number > 8

# Comparaison de durée
{service_name="api-service"} | duration > 1s

# Comparaison d'octets
{service_name="api-service"} | bytes > 1KB
```

### Requêtes Métriques

Agréger les logs en métriques :

```logql
# Compter les logs dans le temps
count_over_time({service_name="api-service"}[5m])

# Taux de logs par seconde
rate({service_name="api-service"}[1m])

# Débit en octets
bytes_rate({service_name="api-service"}[5m])

# Vérifier l'absence de logs
absent_over_time({service_name="api-service"}[1h])
```

### Agrégations Vectorielles

Agréger sur les dimensions de labels :

```logql
# Somme par service
sum by (service_name) (count_over_time({job="app"}[5m]))

# Taux moyen
avg(rate({service_name=~".*"}[1m]))

# Top des services par volume de logs
sum by (service_name) (bytes_rate({job="app"}[5m]))
```

## Requêtes en Temps Réel (WAL)

Par défaut, le service query lit uniquement les données Iceberg validées. Pour interroger également les données qui n'ont pas encore été transférées vers Iceberg (données WAL vieilles de quelques secondes), activez les requêtes WAL dans la configuration du service query :

```yaml
engine:
  wal_query_enabled: true
  wal_metadata_size_hint: 65536  # Bytes for WAL footer reads
```

Lorsque activé, les requêtes lisent depuis les deux sources :

- **Tables Iceberg** — Données historiques, compactées
- **Segments WAL** — Données en temps réel pas encore transférées

**Note :** Les points de terminaison de métadonnées `/labels`, `/label/{name}/values` et `/series` lisent toujours uniquement depuis Iceberg, quel que soit ce paramètre.

## Statut d'Implémentation

| Fonctionnalité | Statut |
|----------------|--------|
| Sélection de Logs | ✅ Implémenté |
| Correspondance de Labels (`=`, `!=`, `=~`, `!~`) | ✅ Implémenté |
| Filtres de Lignes (`\|=`, `!=`, `\|~`, `!~`) | ✅ Implémenté |
| count_over_time | ✅ Implémenté |
| rate | ✅ Implémenté |
| bytes_over_time | ✅ Implémenté |
| bytes_rate | ✅ Implémenté |
| absent_over_time | ✅ Implémenté |
| Agrégations vectorielles (sum, avg, min, max, count) | ✅ Implémenté |
| Parseurs de pipeline (json, logfmt) | ❌ Pas encore |
| Agrégations unwrap | ❌ Pas encore |

## Exemples de Requêtes

### Erreurs Récentes

```logql
{service_name="api-service", severity_text="ERROR"}
```

### Taux d'Erreur par Service

```logql
sum by (service_name) (
  rate({severity_text="ERROR"}[5m])
)
```

### Tendances du Volume de Logs

```logql
sum(count_over_time({job="app"}[1h]))
```

## Utilisation de l'API

### Query Range

```bash
curl -G http://localhost:3100/loki/api/v1/query_range \
  --data-urlencode 'query={service_name="api-service"}' \
  --data-urlencode 'start=1704067200' \
  --data-urlencode 'end=1704153600' \
  --data-urlencode 'limit=1000' \
  -H "X-Scope-OrgID: my-tenant"
```

### Labels Disponibles

```bash
curl http://localhost:3100/loki/api/v1/labels \
  -H "X-Scope-OrgID: my-tenant"
```

### Valeurs de Labels

```bash
curl http://localhost:3100/loki/api/v1/label/service_name/values \
  -H "X-Scope-OrgID: my-tenant"
```

## Étapes Suivantes

- Explorez la [Référence API Loki](../api-reference/loki.md)
- Configurez le [Multi-Tenancy](multi-tenancy.md)
- En savoir plus sur le [Modèle de Données](../architecture/data-model.md)

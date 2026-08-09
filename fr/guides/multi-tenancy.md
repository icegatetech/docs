---
title: Multi-Tenancy
description: Isolez vos tenants dans {{product_name}} - identification, garanties d'isolation des données, configuration Grafana, exemple à trois tenants et bonnes pratiques.
---

# Multi-Tenancy

{% note warning %}

Cette page est en cours de traduction. Pour la documentation complète, veuillez consulter la version anglaise.

{% endnote %}

{{product_name}} est conçu comme un système multi-tenant, fournissant une isolation des données entre différentes organisations ou équipes.

## Identification du Tenant

Les tenants sont identifiés par l'en-tête `X-Scope-OrgID` dans toutes les requêtes API.

```bash
curl -G http://localhost:3100/loki/api/v1/query_range \
  -H "X-Scope-OrgID: tenant-123" \
  --data-urlencode 'query={service_name="api-service"}'
```

## Isolation des Données

Toutes les tables de données sont partitionnées par `tenant_id` :

```sql
partitioning = ARRAY['tenant_id', 'account_id', 'day(timestamp)']
```

## Étapes Suivantes

- En savoir plus sur le [Déploiement](../operations/deployment.md)
- Explorez le [Modèle de Données](../architecture/data-model.md)

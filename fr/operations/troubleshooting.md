---
title: Dépannage
description: Diagnostiquer et résoudre les problèmes courants {{product_name}}
---

# Dépannage

Ce guide aide à diagnostiquer et résoudre les problèmes courants avec IceGate.

## Santé des Services

### Vérifier l'État des Services

```bash
# Service Query
curl http://localhost:3100/ready

# Service Ingest
curl http://localhost:4318/health
```

### Afficher les Logs des Services

```bash
# Docker Compose
docker compose logs -f query
docker compose logs -f ingest
docker compose logs -f maintain
```

## Problèmes de Connexion

### Impossible de se Connecter au Service Query

**Symptômes :**

- Connexion refusée sur le port 3100
- Erreurs de timeout

**Solutions :**

1. Vérifiez que le service est en cours d'exécution :

   ```bash
   docker ps | grep query
   ```

2. Vérifiez la liaison du port :

   ```bash
   netstat -tlnp | grep 3100
   ```

3. Vérifiez les logs du service pour les erreurs :

   ```bash
   docker compose logs query | tail -100
   ```

### Impossible de se Connecter au Stockage Objet

**Symptômes :**

- "Connection refused" vers le stockage objet
- Erreurs d'authentification S3

**Solutions :**

1. Vérifiez que le stockage objet est en cours d'exécution :

   ```bash
   curl http://localhost:9000/health/ready
   ```

2. Vérifiez les identifiants :

   ```bash
   echo $AWS_ACCESS_KEY_ID
   echo $AWS_SECRET_ACCESS_KEY
   ```

3. Testez la connexion S3 :

   ```bash
   aws s3 ls --endpoint-url http://localhost:9000
   ```

### Impossible de se Connecter au Catalogue

**Symptômes :**

- Erreurs "Catalog unavailable"
- Échecs de création de tables

**Solutions :**

1. Vérifiez que Nessie est en cours d'exécution :

   ```bash
   curl http://localhost:19120/api/v1/trees
   ```

2. Vérifiez la configuration du catalogue :

   ```yaml
   catalog:
     backend: !rest
       uri: http://nessie:19120/iceberg
     warehouse: s3://warehouse/
   ```

## Problèmes de Requêtes

### La Requête Retourne des Résultats Vides

**Causes Possibles :**

- Mauvais identifiant de tenant
- Intervalle de temps en dehors de la fenêtre de données
- Données pas encore compactées

**Solutions :**

1. Vérifiez l'en-tête du tenant :

   ```bash
   curl -H "X-Scope-OrgID: correct-tenant" ...
   ```

2. Vérifiez l'intervalle de temps :

   ```bash
   # Lister l'intervalle de temps disponible
   curl http://localhost:3100/loki/api/v1/labels \
     -H "X-Scope-OrgID: my-tenant"
   ```

3. Vérifiez le WAL pour les données récentes :

   ```bash
   aws s3 ls s3://warehouse/wal/ --recursive
   ```

### Timeout de Requête

**Symptômes :**

- Les requêtes prennent trop de temps
- 504 Gateway Timeout

**Solutions :**

1. Ajoutez un filtre d'intervalle de temps :

   ```logql
   {service_name="api"} | timestamp > 1h ago
   ```

2. Réduisez la limite de résultats :

   ```bash
   curl ... --data-urlencode 'limit=100'
   ```

3. Vérifiez le plan de requête :

   ```bash
   curl http://localhost:3100/loki/api/v1/explain \
     --data-urlencode 'query={service_name="api"}' \
     -H "X-Scope-OrgID: my-tenant"
   ```

### Syntaxe de Requête Invalide

**Symptômes :**

- Réponses "parse error"
- 400 Bad Request

**Solutions :**

1. Validez la syntaxe LogQL :
   - Les labels doivent être entre accolades : `{service_name="api"}`
   - Les valeurs de chaîne entre guillemets : `"value"`
   - Format de durée : `[5m]`, `[1h]`

2. Vérifiez les fonctionnalités non supportées :
   - Les parseurs de pipeline (json, logfmt) ne sont pas encore supportés
   - Certaines agrégations ne sont pas implémentées

## Problèmes d'Ingestion

### Les Données n'Apparaissent Pas

**Symptômes :**

- Données envoyées mais la requête retourne vide
- Pas d'erreurs depuis ingest

**Solutions :**

1. Vérifiez que les données ont été acceptées :

   ```bash
   curl -v -X POST http://localhost:4318/v1/logs \
     -H "X-Scope-OrgID: my-tenant" \
     -H "Content-Type: application/json" \
     -d '...'
   ```

2. Vérifiez les fichiers WAL :

   ```bash
   aws s3 ls s3://warehouse/wal/logs/ --recursive
   ```

3. Attendez la compaction (ou interrogez directement le WAL)

### Erreurs d'Ingestion

**Erreurs Courantes :**

- `400 Bad Request` : Format OTLP invalide
- `503 Service Unavailable` : Stockage indisponible
- `429 Too Many Requests` : Limitation de débit

**Solutions :**

1. Validez le format de la charge utile OTLP
2. Vérifiez la connectivité du stockage
3. Réduisez le taux d'ingestion ou augmentez le nombre de réplicas ingest

## Problèmes de Performance

### Requêtes Lentes

1. **Ajoutez des filtres de partition :**

   ```logql
   {tenant_id="my-tenant", service_name="api"}
   ```

2. **Limitez l'intervalle de temps :**

   ```bash
   --data-urlencode 'start=1704067200'
   --data-urlencode 'end=1704153600'
   ```

3. **Vérifiez les statistiques des tables :**

   ```sql
   SHOW STATS FOR icegate.logs;
   ```

### Utilisation Mémoire Élevée

1. Réduisez les requêtes concurrentes
2. Ajoutez des limites de requêtes
3. Augmentez l'allocation mémoire du service

## Obtenir de l'Aide

Si les problèmes persistent :

1. Collectez les informations de diagnostic :

   ```bash
   # Logs des services
   docker compose logs > logs.txt

   # Informations système
   docker stats > stats.txt
   ```

2. Consultez les [GitHub Issues]({{repo_url}}/issues)

3. Incluez :
   - Version d'{{product_name}}
   - Configuration (nettoyée)
   - Messages d'erreur
   - Étapes pour reproduire

## Étapes Suivantes

- Revoir les procédures de [Maintenance](maintenance.md)
- Vérifier la configuration de [Déploiement](deployment.md)
- Comprendre l'[Architecture](../architecture/overview.md)

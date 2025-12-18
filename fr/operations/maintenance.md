---
title: Maintenance
description: Maintenir IceGate pour des performances optimales
---

# Maintenance

{% note warning %}

Cette page est en cours de traduction. Pour la documentation complète, veuillez consulter la version anglaise.

{% endnote %}

Ce guide couvre les opérations de maintenance courantes pour IceGate.

## Compaction des Données

Le service Maintain compacte automatiquement les fichiers WAL en tables Iceberg optimisées.

## Optimisation des Tables

```sql
ALTER TABLE icegate.logs EXECUTE optimize;
```

## Étapes Suivantes

- Mettre en place les procédures de [Dépannage](troubleshooting.md)
- Revoir la configuration de [Déploiement](deployment.md)

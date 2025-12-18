---
title: Dépannage
description: Diagnostiquer et résoudre les problèmes courants IceGate
---

# Dépannage

{% note warning %}

Cette page est en cours de traduction. Pour la documentation complète, veuillez consulter la version anglaise.

{% endnote %}

Ce guide aide à diagnostiquer et résoudre les problèmes courants avec IceGate.

## Santé des Services

### Vérifier l'État des Services

```bash
# Service Query
curl http://localhost:3100/ready

# Service Ingest
curl http://localhost:4318/health
```

## Obtenir de l'Aide

Si les problèmes persistent, consultez les [GitHub Issues](https://github.com/icegatetech/icegate/issues)

## Étapes Suivantes

- Revoir les procédures de [Maintenance](maintenance.md)
- Vérifier la configuration de [Déploiement](deployment.md)

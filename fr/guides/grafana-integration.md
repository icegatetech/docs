---
title: Intégration Grafana
description: Configurer Grafana pour interroger les logs, traces et métriques depuis IceGate
---

# Intégration Grafana

{% note warning %}

Cette page est en cours de traduction. Pour la documentation complète, veuillez consulter la [version anglaise](../../en/guides/grafana-integration.md).

{% endnote %}

Ce guide explique comment connecter Grafana aux API de requête de {{product_name}} : Loki pour les logs (port 3100) et Tempo pour les traces (port 3200), toutes deux implémentées, ainsi que Prometheus pour les métriques (port 9090), qui est prévu mais pas encore fonctionnel — toutes ses routes renvoient `501 Not Implemented`. Vous apprendrez à configurer chaque source de données et à vérifier la connectivité.

## Étapes Suivantes

- Consultez le guide d'[Ingestion de Données](ingestion.md)
- Apprenez à [Interroger les Données](querying.md)

---
title: Intégration Grafana
description: Configurer Grafana pour interroger les logs, traces et métriques depuis IceGate
---

# Intégration Grafana

{% note warning %}

Cette page est en cours de traduction. Pour la documentation complète, veuillez consulter la [version anglaise](../../en/guides/grafana-integration.md).

{% endnote %}

Ce guide explique comment connecter Grafana aux trois API de requête de {{product_name}} : Loki pour les logs (port 3100), Tempo pour les traces (port 3200) et Prometheus pour les métriques (port 9090). Vous apprendrez à configurer chaque source de données et à vérifier la connectivité.

## Étapes Suivantes

- Consultez le guide d'[Ingestion de Données](ingestion.md)
- Apprenez à [Interroger les Données](querying.md)

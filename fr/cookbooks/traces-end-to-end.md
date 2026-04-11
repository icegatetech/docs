---
title: Traçage Distribué de Bout en Bout
description: Instrumenter les services et interroger les traces via l'API Tempo d'IceGate
---

# Traçage Distribué de Bout en Bout

{% note warning %}

Cette page est en cours de traduction. Pour la documentation complète, veuillez consulter la [version anglaise](../../en/cookbooks/traces-end-to-end.md).

{% endnote %}

Ce cookbook explique comment instrumenter vos services avec OpenTelemetry SDK, envoyer les traces à {{product_name}} via OTLP, et les interroger via l'API Tempo (port 3200). Vous apprendrez à configurer la propagation de contexte et à visualiser les traces dans Grafana.

## Étapes Suivantes

- Consultez la [Corrélation des Signaux d'Observabilité](observability-correlation.md)
- Apprenez à configurer l'[Intégration Grafana](../guides/grafana-integration.md)

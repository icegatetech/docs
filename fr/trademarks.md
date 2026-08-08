---
title: Marques
description: Attribution des marques tierces citées dans la documentation {{product_name}}
---

# Marques

{{product_name}} est développé par TripleCloud et distribué sous licence {{license}}.

Cette documentation cite des projets tiers afin de décrire, de manière factuelle, les formats que
{{product_name}} écrit et les protocoles que ses API implémentent. Cet usage nominatif n'implique
aucune affiliation avec les titulaires de ces marques, ni approbation ou parrainage de leur part.

Apache®, Apache Iceberg, Apache Arrow, Apache Parquet, Apache DataFusion, Apache Arrow Flight SQL
ainsi que les logos des projets associés sont des marques déposées ou des marques de The Apache
Software Foundation aux États-Unis et/ou dans d'autres pays.

OpenTelemetry® et Prometheus® sont des marques déposées de The Linux Foundation.

Grafana®, Loki® et Tempo® sont des marques déposées de Raintank, Inc. dba Grafana Labs.

{{product_name}} n'est ni affilié à ces organisations, ni approuvé ou parrainé par elles. Toutes
les autres marques appartiennent à leurs titulaires respectifs.

## Ce que « compatible » signifie ici

Lorsque cette documentation décrit une API comme compatible Loki ou Tempo, cela signifie que
{{product_name}} implémente un sous-ensemble de l'API HTTP de lecture du projet concerné — de quoi
servir les points de terminaison documentés dans les références [Loki](api-reference/loki.md) et [Tempo](api-reference/tempo.md), et
non une réimplémentation complète.

L’API compatible Prometheus est **prévue, pas implémentée** : toutes ses routes renvoient
`501 Not Implemented`, à l’exception de `/-/ready`, qui répond. Sa
[page de référence](api-reference/prometheus.md) documente une surface envisagée, et non une
surface fonctionnelle.

Les pages de référence des API font foi sur ce qui fonctionne aujourd'hui : si un point de
terminaison ou un paramètre n'y figure pas, considérez qu'il n'est pas encore implémenté.

---
title: Trademarks
description: Third-party trademark attribution for the projects {{product_name}} builds on and interoperates with
---

# Trademarks

{{product_name}} is developed by TripleCloud and released under the {{license}} licence.

This documentation names third-party projects in order to describe, factually, which formats
{{product_name}} writes and which wire protocols its APIs implement. Such nominative use does not
imply any affiliation with, endorsement by, or sponsorship from the owners of those marks.

Apache®, Apache Iceberg, Apache Arrow, Apache Parquet, Apache DataFusion, Apache Arrow Flight SQL
and associated project logos are either registered trademarks or trademarks of The Apache Software
Foundation in the United States and/or other countries.

OpenTelemetry® and Prometheus® are registered trademarks of The Linux Foundation.

Grafana®, Loki® and Tempo® are registered trademarks of Raintank, Inc. dba Grafana Labs.

{{product_name}} is not affiliated with, endorsed by, or sponsored by any of these organizations.
All other trademarks are the property of their respective owners.

## What "compatible" means here

Where this documentation describes an API as Loki- or Tempo-compatible, it means {{product_name}}
implements a subset of that project's HTTP read API — enough to serve the endpoints documented in
the [Loki](api-reference/loki.md) and [Tempo](api-reference/tempo.md) API references, not a
complete reimplementation.

The Prometheus-compatible API is **planned, not implemented**: every route returns
`501 Not Implemented` except `/-/ready`, which responds. Its
[reference page](api-reference/prometheus.md) documents an intended surface, not a working one.

The API reference pages are the authoritative statement of what works today: if an endpoint or
parameter is not listed there, assume it is not implemented yet.

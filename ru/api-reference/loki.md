---
title: Справочник Loki API
description: HTTP API эндпоинты совместимые с Loki
---

# Справочник Loki API

{% note warning %}

Эта страница находится в процессе перевода. Полную документацию смотрите в английской версии.

{% endnote %}

IceGate предоставляет HTTP API совместимый с Loki для запросов к логам.

## Базовый URL

```
http://localhost:3100
```

## Аутентификация

Все запросы требуют заголовок `X-Scope-OrgID` для идентификации тенанта.

## Эндпоинты

### Query Range

`GET /loki/api/v1/query_range`

### Labels

`GET /loki/api/v1/labels`

### Label Values

`GET /loki/api/v1/label/{name}/values`

### Series

`GET /loki/api/v1/series`

## Следующие Шаги

- Изучите [Запросы LogQL](../guides/querying.md)
- Изучите [Prometheus API](prometheus.md)

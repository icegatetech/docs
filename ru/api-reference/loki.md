---
title: Справочник Loki API
description: HTTP API эндпоинты, совместимые с Loki, которые обслуживает {{product_name}}
---

# Справочник Loki API

{{product_name}} предоставляет HTTP API, совместимый с Loki®, для запросов к логам — на порту 3100. Ниже
описаны реализованные эндпоинты: это подмножество API Loki, а не полная реализация, поэтому всё,
что здесь не перечислено, следует считать нереализованным. Атрибуцию см. в разделе
[Товарные знаки](../trademarks.md).

## Базовый URL

```
http://localhost:3100
```

## Аутентификация

Все запросы требуют заголовок `X-Scope-OrgID` для идентификации тенанта:

```
X-Scope-OrgID: my-tenant
```

## Эндпоинты

### Instant Query

Запрос логов или метрик в определённый момент времени.

**Эндпоинт:** `GET /loki/api/v1/query` или `POST /loki/api/v1/query`

**Параметры:**

| Параметр | Тип | Обязательный | Описание |
|----------|-----|--------------|----------|
| `query` | string | Да | Запрос LogQL |
| `time` | int | Нет | Временная метка вычисления (Unix секунды или наносекунды). По умолчанию: текущее время |
| `limit` | int | Нет | Максимальное количество записей (по умолчанию: 100) |
| `direction` | string | Нет | `forward` или `backward` (по умолчанию: backward) |

**Пример:**

```bash
curl -G http://localhost:3100/loki/api/v1/query \
  --data-urlencode 'query=count_over_time({service_name="api-service"}[5m])' \
  -H "X-Scope-OrgID: my-tenant"
```

### Query Range

Запрос логов или метрик за диапазон времени.

**Эндпоинт:** `GET /loki/api/v1/query_range`

**Параметры:**

| Параметр | Тип | Обязательный | Описание |
|----------|-----|--------------|----------|
| `query` | string | Да | Запрос LogQL |
| `start` | int | Да | Начальная временная метка (Unix секунды или наносекунды) |
| `end` | int | Да | Конечная временная метка (Unix секунды или наносекунды) |
| `limit` | int | Нет | Максимальное количество записей (по умолчанию: 100) |
| `step` | duration | Нет | Шаг разрешения запроса (например, "5m") |
| `direction` | string | Нет | `forward` или `backward` (по умолчанию: backward) |

**Пример:**

```bash
curl -G http://localhost:3100/loki/api/v1/query_range \
  --data-urlencode 'query={service_name="api-service"}' \
  --data-urlencode 'start=1704067200' \
  --data-urlencode 'end=1704153600' \
  --data-urlencode 'limit=1000' \
  -H "X-Scope-OrgID: my-tenant"
```

**Ответ (Запрос Логов):**

```json
{
  "status": "success",
  "data": {
    "resultType": "streams",
    "result": [
      {
        "stream": {
          "service_name": "api-service",
          "severity_text": "INFO"
        },
        "values": [
          ["1704067200000000000", "Request processed successfully"]
        ]
      }
    ]
  }
}
```

**Ответ (Метрический Запрос):**

```json
{
  "status": "success",
  "data": {
    "resultType": "matrix",
    "result": [
      {
        "metric": {
          "service_name": "api-service"
        },
        "values": [
          [1704067200, "42"],
          [1704067500, "38"]
        ]
      }
    ]
  }
}
```

### Labels

Получение всех имён меток.

**Эндпоинт:** `GET /loki/api/v1/labels`

**Параметры:**

| Параметр | Тип | Обязательный | Описание |
|----------|-----|--------------|----------|
| `start` | int | Нет | Начальная временная метка |
| `end` | int | Нет | Конечная временная метка |

**Пример:**

```bash
curl http://localhost:3100/loki/api/v1/labels \
  -H "X-Scope-OrgID: my-tenant"
```

**Ответ:**

```json
{
  "status": "success",
  "data": [
    "service_name",
    "severity_text",
    "trace_id"
  ]
}
```

### Label Values

Получение значений для конкретной метки.

**Эндпоинт:** `GET /loki/api/v1/label/{name}/values`

**Параметры:**

| Параметр | Тип | Обязательный | Описание |
|----------|-----|--------------|----------|
| `start` | int | Нет | Начальная временная метка |
| `end` | int | Нет | Конечная временная метка |

**Пример:**

```bash
curl http://localhost:3100/loki/api/v1/label/service_name/values \
  -H "X-Scope-OrgID: my-tenant"
```

**Ответ:**

```json
{
  "status": "success",
  "data": [
    "api-service",
    "worker-service",
    "gateway"
  ]
}
```

### Series

Получение наборов меток, соответствующих селекторам.

**Эндпоинт:** `GET /loki/api/v1/series`

**Параметры:**

| Параметр | Тип | Обязательный | Описание |
|----------|-----|--------------|----------|
| `match[]` | string | Да | Селектор(ы) потока логов |
| `start` | int | Нет | Начальная временная метка |
| `end` | int | Нет | Конечная временная метка |

**Пример:**

```bash
curl -G http://localhost:3100/loki/api/v1/series \
  --data-urlencode 'match[]={service_name=~"api-.*"}' \
  -H "X-Scope-OrgID: my-tenant"
```

**Ответ:**

```json
{
  "status": "success",
  "data": [
    {"service_name": "api-service", "severity_text": "INFO"},
    {"service_name": "api-gateway", "severity_text": "ERROR"}
  ]
}
```

### Explain

Получение плана выполнения запроса (расширение {{product_name}}).

**Эндпоинт:** `GET /loki/api/v1/explain`

**Параметры:**

| Параметр | Тип | Обязательный | Описание |
|----------|-----|--------------|----------|
| `query` | string | Да | Запрос LogQL |

**Пример:**

```bash
curl -G http://localhost:3100/loki/api/v1/explain \
  --data-urlencode 'query=count_over_time({service_name="api-service"}[5m])' \
  -H "X-Scope-OrgID: my-tenant"
```

### Health Check

**Эндпоинт:** `GET /ready`

**Ответ:**

```json
{"status": "ready"}
```

## Ответы об Ошибках

Все ошибки возвращают JSON ответ:

```json
{
  "status": "error",
  "errorType": "bad_data",
  "error": "invalid query syntax"
}
```

| Тип Ошибки | HTTP Статус | Описание |
|------------|-------------|----------|
| `bad_data` | 400 | Некорректный запрос или выражение |
| `not_implemented` | 501 | Функция не реализована |
| `internal` | 500 | Внутренняя ошибка сервера |

## Следующие Шаги

- Изучите [Запросы LogQL](../guides/querying.md)
- Изучите [Prometheus API](prometheus.md) — запланирован, пока не реализован
- Смотрите [Tempo API](tempo.md) для трейсов

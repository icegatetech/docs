---
title: Быстрый Старт
description: Загрузка и запрос первых данных наблюдаемости в {{product_name}}
---

# Быстрый Старт

Это руководство проведёт вас через процесс загрузки логов, трейсов и метрик в {{product_name}}, а также их запрос через API и Grafana.

{% note info %}

Данное руководство предполагает, что {{product_name}} уже запущен. См. [Установка](installation.md) для развёртывания через Helm или [Настройка среды разработки](../development/setup.md) для локального окружения.

{% endnote %}

## Загрузка Логов

{{product_name}} принимает данные по протоколу OpenTelemetry (OTLP) через сервис приёма данных.

### Отправка Логов через OTLP HTTP

```bash
curl -X POST http://localhost:4318/v1/logs \
  -H "Content-Type: application/json" \
  -H "X-Scope-OrgID: demo" \
  -d '{
    "resourceLogs": [{
      "resource": {
        "attributes": [
          {"key": "service.name", "value": {"stringValue": "my-service"}}
        ]
      },
      "scopeLogs": [{
        "logRecords": [{
          "timeUnixNano": "'$(date +%s)000000000'",
          "body": {"stringValue": "User login successful"},
          "severityText": "INFO",
          "severityNumber": 9,
          "attributes": [
            {"key": "user.id", "value": {"stringValue": "user-42"}},
            {"key": "http.method", "value": {"stringValue": "POST"}}
          ]
        }]
      }]
    }]
  }'
```

### Отправка Логов через OTLP gRPC

Используйте любой SDK OpenTelemetry. Пример на Python:

```python
from opentelemetry.sdk._logs import LoggerProvider
from opentelemetry.sdk._logs.export import BatchLogRecordProcessor
from opentelemetry.exporter.otlp.proto.grpc._log_exporter import OTLPLogExporter

provider = LoggerProvider()
provider.add_log_record_processor(
    BatchLogRecordProcessor(
        OTLPLogExporter(
            endpoint="localhost:4317",
            headers={"X-Scope-OrgID": "demo"},
            insecure=True,
        )
    )
)
```

## Загрузка Трейсов

Отправьте спаны распределённых трейсов:

```bash
curl -X POST http://localhost:4318/v1/traces \
  -H "Content-Type: application/json" \
  -H "X-Scope-OrgID: demo" \
  -d '{
    "resourceSpans": [{
      "resource": {
        "attributes": [
          {"key": "service.name", "value": {"stringValue": "my-service"}}
        ]
      },
      "scopeSpans": [{
        "spans": [{
          "traceId": "5B8EFFF798038103D269B633813FC60C",
          "spanId": "EEE19B7EC3C1B174",
          "name": "GET /api/users",
          "kind": 2,
          "startTimeUnixNano": "'$(date +%s)000000000'",
          "endTimeUnixNano": "'$(date +%s)100000000'",
          "status": {"code": 1},
          "attributes": [
            {"key": "http.method", "value": {"stringValue": "GET"}},
            {"key": "http.status_code", "value": {"intValue": "200"}}
          ]
        }]
      }]
    }]
  }'
```

## Загрузка Метрик

Отправьте данные метрик:

```bash
curl -X POST http://localhost:4318/v1/metrics \
  -H "Content-Type: application/json" \
  -H "X-Scope-OrgID: demo" \
  -d '{
    "resourceMetrics": [{
      "resource": {
        "attributes": [
          {"key": "service.name", "value": {"stringValue": "my-service"}}
        ]
      },
      "scopeMetrics": [{
        "metrics": [{
          "name": "http_requests_total",
          "sum": {
            "dataPoints": [{
              "startTimeUnixNano": "'$(date +%s)000000000'",
              "timeUnixNano": "'$(date +%s)000000000'",
              "asInt": "42",
              "attributes": [
                {"key": "method", "value": {"stringValue": "GET"}},
                {"key": "status", "value": {"stringValue": "200"}}
              ]
            }],
            "aggregationTemporality": 2,
            "isMonotonic": true
          }
        }]
      }]
    }]
  }'
```

## Запрос Логов с помощью LogQL

{{product_name}} предоставляет API, совместимый с Loki, через сервис запросов (порт 3100) — подмножество API
Loki, перечисленное в [справочнике API](../api-reference/loki.md).

### Базовый Запрос Логов

```bash
curl -G http://localhost:3100/loki/api/v1/query_range \
  --data-urlencode 'query={service_name="my-service"}' \
  --data-urlencode 'start='$(date -d '1 hour ago' +%s 2>/dev/null || date -v-1H +%s) \
  --data-urlencode 'end='$(date +%s) \
  --data-urlencode 'limit=100' \
  -H "X-Scope-OrgID: demo"
```

### Фильтрация по Уровню Серьёзности

```bash
curl -G http://localhost:3100/loki/api/v1/query_range \
  --data-urlencode 'query={service_name="my-service", severity_text="ERROR"}' \
  --data-urlencode 'start='$(date -d '1 hour ago' +%s 2>/dev/null || date -v-1H +%s) \
  --data-urlencode 'end='$(date +%s) \
  -H "X-Scope-OrgID: demo"
```

### Поиск по Содержимому Логов

```bash
curl -G http://localhost:3100/loki/api/v1/query_range \
  --data-urlencode 'query={service_name="my-service"} |= "login"' \
  --data-urlencode 'start='$(date -d '1 hour ago' +%s 2>/dev/null || date -v-1H +%s) \
  --data-urlencode 'end='$(date +%s) \
  -H "X-Scope-OrgID: demo"
```

### Агрегация Логов в Метрики

```bash
# Подсчёт логов за 5-минутные окна
curl -G http://localhost:3100/loki/api/v1/query_range \
  --data-urlencode 'query=count_over_time({service_name="my-service"}[5m])' \
  --data-urlencode 'start='$(date -d '1 hour ago' +%s 2>/dev/null || date -v-1H +%s) \
  --data-urlencode 'end='$(date +%s) \
  --data-urlencode 'step=300' \
  -H "X-Scope-OrgID: demo"

# Частота ошибок в секунду
curl -G http://localhost:3100/loki/api/v1/query_range \
  --data-urlencode 'query=rate({severity_text="ERROR"}[1m])' \
  --data-urlencode 'start='$(date -d '1 hour ago' +%s 2>/dev/null || date -v-1H +%s) \
  --data-urlencode 'end='$(date +%s) \
  --data-urlencode 'step=60' \
  -H "X-Scope-OrgID: demo"
```

## Обзор Меток и Серий

### Список Всех Меток

```bash
curl http://localhost:3100/loki/api/v1/labels \
  -H "X-Scope-OrgID: demo"
```

### Получение Значений Метки

```bash
curl http://localhost:3100/loki/api/v1/label/service_name/values \
  -H "X-Scope-OrgID: demo"
```

### Поиск Совпадающих Серий

```bash
curl -G http://localhost:3100/loki/api/v1/series \
  --data-urlencode 'match[]={service_name=~"my-.*"}' \
  -H "X-Scope-OrgID: demo"
```

## Использование Grafana

{{product_name}} совместим с источником данных Loki в Grafana для визуализации логов и создания дашбордов.

### Добавление {{product_name}} как Источника Данных

1. Откройте Grafana (по умолчанию: [http://localhost:3000](http://localhost:3000))
2. Перейдите в **Connections** > **Data sources** > **Add data source**
3. Выберите **Loki**
4. Укажите URL: `http://icegate-query:3100` (или `http://localhost:3100` для локального доступа)
5. В разделе **HTTP Headers** добавьте:
   - Header: `X-Scope-OrgID`
   - Value: `demo`
6. Нажмите **Save & Test**

### Исследование Логов

1. Перейдите в **Explore**
1. Выберите источник данных **Loki**
1. Введите запрос LogQL: `{service_name="my-service"}`
1. Нажмите **Run query**
1. Переключайтесь между режимами **Logs** и **Graph**

### Создание Дашборда

1. Перейдите в **Dashboards** > **New** > **New Dashboard**
2. Добавьте **панель Logs**:
   - Query: `{service_name="my-service"}`
   - Визуализация: Logs
3. Добавьте **панель Time series** для частоты ошибок:
   - Query: `sum by (service_name) (rate({severity_text="ERROR"}[5m]))`
   - Визуализация: Time series
4. Добавьте **панель Stat** для объёма логов:
   - Query: `sum(count_over_time({service_name="my-service"}[1h]))`
   - Визуализация: Stat

### Готовые Дашборды

При развёртывании с overlay-конфигурациями Kustomize или Docker Compose, Grafana поставляется с предварительно настроенными дашбордами {{product_name}} для метрик сервисов приёма данных и запросов.

## Использование OpenTelemetry Collector

Для производственных нагрузок используйте [OpenTelemetry Collector](https://opentelemetry.io/docs/collector/) для пересылки данных из ваших приложений в {{product_name}}:

```yaml
# otel-collector-config.yaml
exporters:
  otlp/icegate:
    endpoint: icegate-ingest:4317
    tls:
      insecure: true
    headers:
      X-Scope-OrgID: my-tenant

service:
  pipelines:
    logs:
      receivers: [otlp]
      exporters: [otlp/icegate]
    traces:
      receivers: [otlp]
      exporters: [otlp/icegate]
    metrics:
      receivers: [otlp]
      exporters: [otlp/icegate]
```

## Мультитенантность

{{product_name}} изолирует данные по тенантам с помощью заголовка `X-Scope-OrgID`. Данные каждого тенанта физически разделены.

```bash
# Загрузка данных для тенанта "team-a"
curl -X POST http://localhost:4318/v1/logs \
  -H "X-Scope-OrgID: team-a" \
  -H "Content-Type: application/json" \
  -d '...'

# Запрос видит только данные team-a
curl -G http://localhost:3100/loki/api/v1/query_range \
  --data-urlencode 'query={service_name="api"}' \
  -H "X-Scope-OrgID: team-a"
```

Подробнее см. [Мультитенантность](../guides/multi-tenancy.md).

## Дальнейшие Шаги

- Изучите [запросы LogQL](../guides/querying.md) подробнее
- Ознакомьтесь со справочником [API Loki](../api-reference/loki.md)
- Настройте пайплайны [приёма данных](../guides/ingestion.md)
- Разберитесь в [модели данных](../architecture/data-model.md)

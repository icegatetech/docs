---
title: API Загрузки OTLP
description: Точки доступа OpenTelemetry Protocol для загрузки данных
---

# API Загрузки OTLP

IceGate принимает данные наблюдаемости через протокол OpenTelemetry (OTLP). Поддерживаются транспорты HTTP и gRPC.

## Протоколы

| Протокол | Порт по умолчанию | Типы содержимого |
|----------|-------------------|------------------|
| HTTP | 4318 | `application/x-protobuf`, `application/json` |
| gRPC | 4317 | Protobuf (стандартный gRPC) |

## Аутентификация

Все запросы требуют заголовок `X-Scope-OrgID` (регистронезависимый) для идентификации арендатора:

```
X-Scope-OrgID: my-tenant
```

**Правила для идентификатора арендатора:**

- Допустимые символы: буквенно-цифровые ASCII, дефисы (`-`), подчёркивания (`_`)
- Значение по умолчанию: `default` (когда заголовок отсутствует или недействителен)

## Точки доступа HTTP

### Загрузка логов

**Точка доступа:** `POST /v1/logs`

Загрузка записей логов OpenTelemetry.

**Заголовки:**

| Заголовок | Обязателен | Описание |
|-----------|-----------|----------|
| `Content-Type` | Нет | `application/x-protobuf` (по умолчанию) или `application/json` |
| `X-Scope-OrgID` | Нет | Идентификатор арендатора (по умолчанию: `default`) |

**Пример (JSON):**

```bash
curl -X POST http://localhost:4318/v1/logs \
  -H "Content-Type: application/json" \
  -H "X-Scope-OrgID: my-tenant" \
  -d '{
    "resourceLogs": [{
      "resource": {
        "attributes": [
          {"key": "service.name", "value": {"stringValue": "api-service"}}
        ]
      },
      "scopeLogs": [{
        "logRecords": [{
          "timeUnixNano": "1704067200000000000",
          "body": {"stringValue": "Request processed successfully"},
          "severityText": "INFO",
          "severityNumber": 9,
          "attributes": [
            {"key": "http.method", "value": {"stringValue": "GET"}},
            {"key": "http.status_code", "value": {"intValue": "200"}}
          ]
        }]
      }]
    }]
  }'
```

**Пример (Protobuf):**

```bash
# Использование SDK или коллектора OpenTelemetry с кодированием protobuf
curl -X POST http://localhost:4318/v1/logs \
  -H "Content-Type: application/x-protobuf" \
  -H "X-Scope-OrgID: my-tenant" \
  --data-binary @logs.pb
```

**Ответ (200 OK):**

```json
{
  "partialSuccess": {
    "rejectedLogRecords": 0,
    "errorMessage": ""
  }
}
```

### Загрузка трейсов

**Точка доступа:** `POST /v1/traces`

Загрузка спанов трейсов OpenTelemetry.

```bash
curl -X POST http://localhost:4318/v1/traces \
  -H "Content-Type: application/json" \
  -H "X-Scope-OrgID: my-tenant" \
  -d '{
    "resourceSpans": [{
      "resource": {
        "attributes": [
          {"key": "service.name", "value": {"stringValue": "api-service"}}
        ]
      },
      "scopeSpans": [{
        "spans": [{
          "traceId": "5B8EFFF798038103D269B633813FC60C",
          "spanId": "EEE19B7EC3C1B174",
          "name": "GET /api/users",
          "kind": 2,
          "startTimeUnixNano": "1704067200000000000",
          "endTimeUnixNano": "1704067200100000000",
          "status": {"code": 1}
        }]
      }]
    }]
  }'
```

### Загрузка метрик

**Точка доступа:** `POST /v1/metrics`

Загрузка метрик OpenTelemetry.

```bash
curl -X POST http://localhost:4318/v1/metrics \
  -H "Content-Type: application/json" \
  -H "X-Scope-OrgID: my-tenant" \
  -d '{
    "resourceMetrics": [{
      "resource": {
        "attributes": [
          {"key": "service.name", "value": {"stringValue": "api-service"}}
        ]
      },
      "scopeMetrics": [{
        "metrics": [{
          "name": "http_requests_total",
          "sum": {
            "dataPoints": [{
              "startTimeUnixNano": "1704067200000000000",
              "timeUnixNano": "1704067260000000000",
              "asInt": "1234"
            }],
            "aggregationTemporality": 2,
            "isMonotonic": true
          }
        }]
      }]
    }]
  }'
```

### Проверка состояния

**Точка доступа:** `GET /health`

```bash
curl http://localhost:4318/health
```

**Ответ:**

```json
{"status": "healthy"}
```

## Сервисы gRPC

Сервер gRPC реализует стандартные сервисы коллектора OpenTelemetry на порту 4317.

### Сервисы

| Сервис | Метод | Описание |
|--------|-------|----------|
| `opentelemetry.proto.collector.logs.v1.LogsService` | `Export` | Загрузка записей логов |
| `opentelemetry.proto.collector.trace.v1.TraceService` | `Export` | Загрузка спанов трейсов |
| `opentelemetry.proto.collector.metrics.v1.MetricsService` | `Export` | Загрузка метрик |

### Метаданные арендатора

Передайте идентификатор арендатора в качестве метаданных gRPC:

```
x-scope-orgid: my-tenant
```

### Пример с grpcurl

```bash
# Просмотр доступных сервисов
grpcurl -plaintext localhost:4317 list

# Отправка логов (требуется proto-файл)
grpcurl -plaintext \
  -H "x-scope-orgid: my-tenant" \
  -d '{"resourceLogs": [...]}' \
  localhost:4317 \
  opentelemetry.proto.collector.logs.v1.LogsService/Export
```

## Использование SDK OpenTelemetry

### Python

```python
from opentelemetry.sdk._logs import LoggerProvider
from opentelemetry.sdk._logs.export import BatchLogRecordProcessor
from opentelemetry.exporter.otlp.proto.grpc._log_exporter import OTLPLogExporter

provider = LoggerProvider()
provider.add_log_record_processor(
    BatchLogRecordProcessor(
        OTLPLogExporter(
            endpoint="localhost:4317",
            headers={"X-Scope-OrgID": "my-tenant"},
            insecure=True,
        )
    )
)
```

### Go

```go
import "go.opentelemetry.io/otel/exporters/otlp/otlplog/otlploggrpc"

exporter, _ := otlploggrpc.New(ctx,
    otlploggrpc.WithEndpoint("localhost:4317"),
    otlploggrpc.WithInsecure(),
    otlploggrpc.WithHeaders(map[string]string{
        "X-Scope-OrgID": "my-tenant",
    }),
)
```

### Коллектор OpenTelemetry

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

## Ответы об ошибках

### Ошибки HTTP

| HTTP-код | Тип ошибки | Описание |
|----------|-----------|----------|
| 400 | Bad Request | Некорректная полезная нагрузка OTLP или кодирование |
| 408 | Request Timeout | Запрос отменён |
| 500 | Internal Server Error | Сбой хранилища или обработки |
| 501 | Not Implemented | Точка доступа ещё не реализована |
| 503 | Service Unavailable | Очередь WAL заполнена или хранилище недоступно |

### Коды состояния gRPC

| Код gRPC | Описание |
|----------|----------|
| `INVALID_ARGUMENT` | Некорректная полезная нагрузка или кодирование |
| `UNIMPLEMENTED` | Сервис ещё не реализован |
| `INTERNAL` | Сбой хранилища или обработки |
| `CANCELLED` | Запрос отменён |
| `UNAVAILABLE` | Очередь WAL заполнена или хранилище недоступно |

## Нагрузочное тестирование с IceGen

[IceGen](https://github.com/icegatetech/icegen) — это высокопроизводительный генератор логов OpenTelemetry для тестирования загрузки данных в IceGate.

### Установка

```bash
git clone https://github.com/icegatetech/icegen.git
cd icegen
cargo build --release
```

### Использование

```bash
# Отправить 100 логов через HTTP JSON
otel-log-generator otel \
  --endpoint http://localhost:4318/v1/logs \
  --count 100

# Отправить через gRPC с 8 арендаторами и 20 параллельными воркерами
otel-log-generator otel \
  --endpoint http://localhost:4317 \
  --transport grpc \
  --tenant-count 8 \
  --count 1000 \
  --concurrency 20

# Непрерывный режим с кодированием protobuf
otel-log-generator otel \
  --endpoint http://localhost:4318/v1/logs \
  --use-protobuf \
  --continuous \
  --message-interval-ms 100 \
  --concurrency 10

# Агрегированные сообщения (5 записей на запрос)
otel-log-generator otel \
  --endpoint http://localhost:4318/v1/logs \
  --records-per-message 5 \
  --count 100

# Тестирование обработки ошибок с 10% невалидных записей
otel-log-generator otel \
  --endpoint http://localhost:4318/v1/logs \
  --invalid-record-percent 10.0 \
  --count 100
```

### Параметры IceGen

| Параметр | По умолчанию | Описание |
|----------|-------------|----------|
| `--endpoint` | — | URL точки доступа OTLP |
| `--transport` | `http` | Транспорт: `http` или `grpc` |
| `--use-protobuf` | `false` | Использовать кодирование protobuf (только HTTP) |
| `--count` | `1` | Количество сообщений для отправки |
| `--concurrency` | `1` | Количество параллельных воркеров |
| `--message-interval-ms` | `0` | Задержка между сообщениями (мс) |
| `--records-per-message` | `1` | Записей логов на сообщение |
| `--continuous` | `false` | Непрерывная работа |
| `--tenant-id` | `default` | Идентификатор арендатора |
| `--tenant-count` | `1` | Количество случайных арендаторов |
| `--invalid-record-percent` | `0.0` | Процент невалидных записей |

## Поток данных

1. Клиент отправляет данные OTLP в сервис загрузки (Ingest)
2. Ingest валидирует и преобразует данные в Arrow RecordBatch
3. Записи сортируются в группы строк WAL по ключам партиции
4. Данные записываются в WAL (Parquet в объектном хранилище) через ограниченную очередь
5. Клиенту отправляется подтверждение (доставка ровно один раз)
6. Процесс Shift асинхронно компактирует WAL в таблицы Iceberg

## Дальнейшие шаги

- Запрашивайте загруженные данные с помощью [API Loki](loki.md)
- Узнайте о [модели данных](../architecture/data-model.md)
- Настройте пайплайны [загрузки данных](../guides/ingestion.md)

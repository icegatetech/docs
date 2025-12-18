---
title: Быстрый Старт
description: Начните работу с IceGate за 5 минут
---

# Быстрый Старт

Это руководство проведёт вас через загрузку первых логов и их запрос в IceGate.

## Запуск Среды Разработки

Запустите полный стек IceGate с помощью Docker Compose:

```bash
make dev
```

Это запустит следующие сервисы:

| Сервис | Порт | Описание |
|--------|------|----------|
| MinIO (S3) | 9000, 9001 | Объектное хранилище |
| Nessie | 19120 | Каталог Iceberg |
| Сервис Query | 3100 | API совместимый с Loki |
| Grafana | 3000 | Дашборд наблюдаемости |
| Trino | 8080 | SQL движок запросов |

## Проверка Работоспособности Сервисов

Убедитесь, что все сервисы работают:

```bash
# Проверить Loki API
curl http://localhost:3100/ready

# Проверить Grafana
curl http://localhost:3000/api/health
```

## Отправка Тестовых Логов

IceGate принимает логи через протокол OpenTelemetry (OTLP).

### Используя curl (OTLP HTTP)

```bash
curl -X POST http://localhost:4318/v1/logs \
  -H "Content-Type: application/json" \
  -H "X-Scope-OrgID: demo" \
  -d '{
    "resourceLogs": [{
      "resource": {
        "attributes": [
          {"key": "service.name", "value": {"stringValue": "мой-сервис"}}
        ]
      },
      "scopeLogs": [{
        "logRecords": [{
          "timeUnixNano": "'$(date +%s)000000000'",
          "body": {"stringValue": "Привет от IceGate!"},
          "severityText": "INFO"
        }]
      }]
    }]
  }'
```

## Запросы к Логам

### Используя Loki API

Делайте запросы к логам через API совместимый с Loki:

```bash
curl -G http://localhost:3100/loki/api/v1/query_range \
  --data-urlencode 'query={service_name="мой-сервис"}' \
  --data-urlencode 'start='$(date -v-1H +%s) \
  --data-urlencode 'end='$(date +%s) \
  -H "X-Scope-OrgID: demo"
```

### Используя Grafana

1. Откройте Grafana по адресу [http://localhost:3000](http://localhost:3000)
2. Перейдите в Explore
3. Выберите источник данных Loki
4. Введите запрос LogQL: `{service_name="мой-сервис"}`
5. Нажмите "Run query"

## Запросы с LogQL

IceGate поддерживает LogQL для запросов к логам:

```logql
# Фильтр по сервису
{service_name="мой-сервис"}

# Фильтр по содержимому строки
{service_name="мой-сервис"} |= "ошибка"

# Подсчёт логов за время
count_over_time({service_name="мой-сервис"}[5m])

# Частота логов
rate({service_name="мой-сервис"}[1m])
```

## Следующие Шаги

- Узнайте о [Конфигурации](configuration.md)
- Изучите [Загрузку Данных](../guides/ingestion.md) подробнее
- Поймите возможности [Запросов](../guides/querying.md)

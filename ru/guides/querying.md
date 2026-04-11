---
title: Запросы к Данным
description: Запросы к логам, трейсам и метрикам с LogQL, PromQL и TraceQL
---

# Запросы к Данным

IceGate предоставляет API совместимые с Loki, Prometheus и Tempo для запросов к данным наблюдаемости.

## LogQL для Логов

LogQL - язык запросов для логов, совместимый с Grafana Loki.

### Селектор Потока Логов

Выбор логов по меткам:

```logql
# Выбор по имени сервиса
{service_name="api-service"}

# Несколько меток
{service_name="api-service", severity_text="ERROR"}

# Сопоставление по регулярному выражению
{service_name=~"api-.*"}

# Отрицательное сопоставление
{service_name!="internal-service"}
```

### Фильтры Строк

Фильтрация строк логов по содержимому:

```logql
# Содержит
{service_name="api-service"} |= "error"

# Не содержит
{service_name="api-service"} != "debug"

# Сопоставление по regex
{service_name="api-service"} |~ "status=[45][0-9][0-9]"

# Не совпадает с regex
{service_name="api-service"} !~ "health"
```

### Фильтры Меток

Фильтрация по значениям меток:

```logql
# Числовое сравнение
{service_name="api-service"} | severity_number > 8

# Сравнение длительности
{service_name="api-service"} | duration > 1s

# Сравнение байтов
{service_name="api-service"} | bytes > 1KB
```

### Метрические Запросы

Агрегация логов в метрики:

```logql
# Подсчёт логов за время
count_over_time({service_name="api-service"}[5m])

# Частота логов в секунду
rate({service_name="api-service"}[1m])

# Пропускная способность в байтах
bytes_rate({service_name="api-service"}[5m])

# Проверка отсутствия логов
absent_over_time({service_name="api-service"}[1h])
```

### Векторные Агрегации

Агрегация по измерениям меток:

```logql
# Сумма по сервису
sum by (service_name) (count_over_time({job="app"}[5m]))

# Средняя частота
avg(rate({service_name=~".*"}[1m]))

# Топ сервисов по объёму логов
sum by (service_name) (bytes_rate({job="app"}[5m]))
```

## Запросы в Реальном Времени (WAL)

По умолчанию сервис запросов читает только зафиксированные данные Iceberg. Чтобы также запрашивать данные, которые ещё не были перенесены в Iceberg (данные WAL возрастом в секунды), включите WAL-запросы в конфигурации сервиса запросов:

```yaml
engine:
  wal_query_enabled: true
  wal_metadata_size_hint: 65536  # Bytes for WAL footer reads
```

При включении запросы читают из обоих источников:

- **Таблицы Iceberg** — Исторические, компактированные данные
- **Сегменты WAL** — Данные в реальном времени, ещё не перенесённые

**Примечание:** Эндпоинты метаданных `/labels`, `/label/{name}/values` и `/series` всегда читают только из Iceberg, независимо от этой настройки.

## Статус Реализации

| Возможность | Статус |
|-------------|--------|
| Выбор логов | ✅ Реализовано |
| Сопоставление меток (`=`, `!=`, `=~`, `!~`) | ✅ Реализовано |
| Фильтры строк (`\|=`, `!=`, `\|~`, `!~`) | ✅ Реализовано |
| count_over_time | ✅ Реализовано |
| rate | ✅ Реализовано |
| bytes_over_time | ✅ Реализовано |
| bytes_rate | ✅ Реализовано |
| absent_over_time | ✅ Реализовано |
| Векторные агрегации (sum, avg, min, max, count) | ✅ Реализовано |
| Pipeline парсеры (json, logfmt) | ❌ Пока нет |
| Unwrap агрегации | ❌ Пока нет |

## Примеры Запросов

### Недавние Ошибки

```logql
{service_name="api-service", severity_text="ERROR"}
```

### Частота Ошибок по Сервису

```logql
sum by (service_name) (
  rate({severity_text="ERROR"}[5m])
)
```

### Тренды Объёма Логов

```logql
sum(count_over_time({job="app"}[1h]))
```

## Использование API

### Query Range

```bash
curl -G http://localhost:3100/loki/api/v1/query_range \
  --data-urlencode 'query={service_name="api-service"}' \
  --data-urlencode 'start=1704067200' \
  --data-urlencode 'end=1704153600' \
  --data-urlencode 'limit=1000' \
  -H "X-Scope-OrgID: my-tenant"
```

### Доступные Метки

```bash
curl http://localhost:3100/loki/api/v1/labels \
  -H "X-Scope-OrgID: my-tenant"
```

### Значения Меток

```bash
curl http://localhost:3100/loki/api/v1/label/service_name/values \
  -H "X-Scope-OrgID: my-tenant"
```

## Следующие Шаги

- Изучите [Справочник Loki API](../api-reference/loki.md)
- Настройте [Мультитенантность](multi-tenancy.md)
- Узнайте о [Модели Данных](../architecture/data-model.md)

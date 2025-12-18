---
title: Запросы к Данным
description: Запросы к логам, трейсам и метрикам с LogQL, PromQL и TraceQL
---

# Запросы к Данным

{% note warning %}

Эта страница находится в процессе перевода. Полную документацию смотрите в английской версии.

{% endnote %}

IceGate предоставляет API совместимые с Loki, Prometheus и Tempo для запросов к данным наблюдаемости.

## LogQL для Логов

LogQL - язык запросов для логов, совместимый с Grafana Loki.

### Селектор Потока Логов

```logql
# Выбор по имени сервиса
{service_name="api-service"}

# Несколько меток
{service_name="api-service", severity_text="ERROR"}
```

### Фильтры Строк

```logql
# Содержит
{service_name="api-service"} |= "ошибка"

# Не содержит
{service_name="api-service"} != "debug"
```

### Метрические Запросы

```logql
# Подсчёт логов за время
count_over_time({service_name="api-service"}[5m])

# Частота логов в секунду
rate({service_name="api-service"}[1m])
```

## Следующие Шаги

- Изучите [Справочник Loki API](../api-reference/loki.md)
- Настройте [Мультитенантность](multi-tenancy.md)

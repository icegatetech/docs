---
title: Загрузка Данных
description: Загрузка логов, трейсов и метрик в IceGate
---

# Загрузка Данных

{% note warning %}

Эта страница находится в процессе перевода. Полную документацию смотрите в английской версии.

{% endnote %}

IceGate принимает данные наблюдаемости через протокол OpenTelemetry (OTLP).

## Поддерживаемые Протоколы

| Протокол | Порт | Описание |
|----------|------|----------|
| OTLP HTTP | 4318 | HTTP/JSON или HTTP/Protobuf |
| OTLP gRPC | 4317 | gRPC/Protobuf |

## Идентификация Тенанта

IceGate мультитенантный. Укажите тенанта через заголовок `X-Scope-OrgID`:

```bash
curl -X POST http://localhost:4318/v1/logs \
  -H "X-Scope-OrgID: tenant-123" \
  -H "Content-Type: application/json" \
  -d '...'
```

## Следующие Шаги

- Узнайте как [Делать Запросы к Данным](querying.md)
- Настройте [Мультитенантность](multi-tenancy.md)

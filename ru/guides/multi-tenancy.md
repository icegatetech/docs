---
title: Мультитенантность
description: Настройка и использование изоляции мультитенантности в IceGate
---

# Мультитенантность

{% note warning %}

Эта страница находится в процессе перевода. Полную документацию смотрите в английской версии.

{% endnote %}

IceGate разработан как мультитенантная система, обеспечивающая изоляцию данных между разными организациями или командами.

## Идентификация Тенанта

Тенанты идентифицируются заголовком `X-Scope-OrgID` во всех API запросах.

```bash
curl -G http://localhost:3100/loki/api/v1/query_range \
  -H "X-Scope-OrgID: tenant-123" \
  --data-urlencode 'query={service_name="api-service"}'
```

## Изоляция Данных

Все таблицы данных партиционированы по `tenant_id`:

```sql
partitioning = ARRAY['tenant_id', 'account_id', 'day(timestamp)']
```

## Следующие Шаги

- Узнайте о [Развёртывании](../operations/deployment.md)
- Изучите [Модель Данных](../architecture/data-model.md)

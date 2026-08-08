---
title: Конфигурация
description: Настройка компонентов {{product_name}}
---

# Конфигурация

{{product_name}} использует файлы конфигурации YAML или TOML. Формат определяется автоматически по расширению файла (`.yaml`/`.yml` для YAML, `.toml` для TOML).

## Использование CLI

Каждый бинарный файл принимает файл конфигурации через флаг `-c` / `--config`:

```bash
# Сервис Ingest
ingest run -c /etc/icegate/ingest.yaml

# Сервис Query
query run -c /etc/icegate/query.yaml

# Сервис Maintain (миграция схемы)
maintain migrate create -c /etc/icegate/maintain.yaml
maintain migrate upgrade -c /etc/icegate/maintain.yaml

# Показать версию
ingest version
query version
```

## Переменные Окружения

| Переменная | Описание | По умолчанию |
|------------|----------|--------------|
| `AWS_ACCESS_KEY_ID` | Ключ доступа S3 (используется хранилищем и job manager) | — |
| `AWS_SECRET_ACCESS_KEY` | Секретный ключ S3 | — |
| `OTEL_EXPORTER_OTLP_ENDPOINT` | Эндпоинт трейсинга OpenTelemetry (запасной, если `tracing.otlp_endpoint` не задан) | — |
| `RUST_LOG` | Фильтр уровня логирования (например, `info`, `debug`, `info,icegate_query=debug`) | `info` |

## Конфигурация Каталога

Секция `catalog` настраивает каталог Apache Iceberg. Она является общей для всех сервисов (Ingest, Query, Maintain).

```yaml
catalog:
  backend: !rest
    uri: http://nessie:19120/iceberg
  warehouse: s3://warehouse/
  properties:
    prefix: main
```

### Параметры Каталога

| Параметр | Тип | Обязательный | По умолчанию | Описание |
|----------|-----|--------------|--------------|----------|
| `backend` | enum | Да | `memory` | Тип бэкенда каталога (см. ниже) |
| `warehouse` | string | Да | — | Расположение хранилища (например, `s3://warehouse/`) |
| `properties` | map | Нет | `{}` | Дополнительные свойства каталога |
| `cache` | object | Нет | — | Конфигурация IO-кэша (см. [Конфигурация Кэша](#конфигурация-кэша)) |

### Бэкенды Каталога

#### REST Каталог (Nessie)

```yaml
catalog:
  backend: !rest
    uri: http://nessie:19120/iceberg
  warehouse: s3://warehouse/
  properties:
    prefix: main
```

| Параметр | Тип | Обязательный | Описание |
|----------|-----|--------------|----------|
| `uri` | string | Да | URL эндпоинта REST каталога (должен начинаться с `http://` или `https://`) |

#### AWS S3 Tables

```yaml
catalog:
  backend: !s3tables
    table_bucket_arn: arn:aws:s3tables:us-east-1:123456789012:bucket/my-tables
  warehouse: s3://warehouse/
```

| Параметр | Тип | Обязательный | Описание |
|----------|-----|--------------|----------|
| `table_bucket_arn` | string | Да | ARN бакета S3 Tables (формат: `arn:aws:s3tables:<region>:<account>:bucket/<name>`) |

#### AWS Glue

```yaml
catalog:
  backend: !glue
    catalog_id: "123456789012"
  warehouse: s3://warehouse/
```

| Параметр | Тип | Обязательный | Описание |
|----------|-----|--------------|----------|
| `catalog_id` | string | Нет | 12-значный идентификатор аккаунта AWS. Если не указан, используется каталог аккаунта по умолчанию |

#### In-Memory (Тестирование)

```yaml
catalog:
  backend: !memory
  warehouse: /tmp/icegate/warehouse
```

### Конфигурация Кэша

Опциональная секция `cache` включает гибридный кэш foyer (память + диск) для уменьшения обращений к S3 при повторных чтениях. Рекомендуется для продакшен сервисов запросов.

```yaml
catalog:
  backend: !rest
    uri: http://nessie:19120/iceberg
  warehouse: s3://warehouse/
  cache:
    memory_size_mb: 1024
    disk_dir: /tmp/icegate/cache
    disk_size_mb: 4096
    stat_ttl_secs: 300
    max_write_cache_size_mb: 128
    prefetch:
      max_prefetch_bytes: 1048576
```

| Параметр | Тип | Обязательный | По умолчанию | Описание |
|----------|-----|--------------|--------------|----------|
| `memory_size_mb` | integer | Да | — | Ёмкость кэша в памяти в MiB |
| `disk_dir` | string | Да | — | Директория для дискового кэша |
| `disk_size_mb` | integer | Да | — | Ёмкость дискового кэша в MiB |
| `stat_ttl_secs` | integer | Нет | — | TTL в секундах для кэширования ответов S3 HEAD |
| `max_write_cache_size_mb` | integer | Нет | — | Макс. размер значения в MiB для кэширования при записи. Файлы большего размера обходят кэш |
| `prefetch.max_prefetch_bytes` | integer | Нет | — | Макс. байт для предзагрузки блоков столбцов Parquet |

## Конфигурация Хранилища

Секция `storage` настраивает бэкенд объектного хранилища. Является общей для всех сервисов.

### S3 / S3-Совместимое (MinIO)

```yaml
storage:
  backend: !s3
    bucket: warehouse
    region: us-east-1
    endpoint: http://minio:9000
```

| Параметр | Тип | Обязательный | По умолчанию | Описание |
|----------|-----|--------------|--------------|----------|
| `bucket` | string | Да | — | Имя бакета S3 |
| `region` | string | Да | — | Регион AWS |
| `endpoint` | string | Нет | — | URL кастомного эндпоинта для S3-совместимого хранилища (MinIO и др.) |

### Локальная Файловая Система

```yaml
storage:
  backend: !filesystem
    root_path: /var/data/icegate
```

| Параметр | Тип | Обязательный | Описание |
|----------|-----|--------------|----------|
| `root_path` | string | Да | Корневая директория для хранения данных |

### In-Memory (Тестирование)

```yaml
storage:
  backend: !memory
```

## Конфигурация Сервиса Ingest

Полный справочник сервиса Ingest (`ingest run -c ingest.yaml`).

### Полный Пример

```yaml
catalog:
  backend: !rest
    uri: http://nessie:19120/iceberg
  warehouse: s3://warehouse/
  properties:
    prefix: main

storage:
  backend: !s3
    bucket: warehouse
    region: us-east-1
    endpoint: http://minio:9000

queue:
  common:
    base_path: s3://queue/
    channel_capacity: 1024
    max_row_group_size: 8192
  write:
    write_retries: 5
    compression: zstd
    records_per_flush_multiplier: 1
    max_bytes_per_flush: 67108864
    flush_interval_ms: 200

shift:
  read:
    max_record_batches_per_task: 1024
    max_input_bytes_per_task: 67108864
    plan_segment_read_parallelism: 8
    shift_segment_read_parallelism: 8
  write:
    row_group_size: 8192
    max_file_size_mb: 64
    table_cache_ttl_secs: 60
  jobsmanager:
    worker_count: 4
    poll_interval_ms: 1000
    iteration_interval_millisecs: 30000
    storage:
      endpoint: http://minio:9000
      bucket: jobs
      prefix: shifter
      region: us-east-1
      use_ssl: false
      job_state_codec: json
      request_timeout_secs: 5

otlp_http:
  enabled: true
  host: 0.0.0.0
  port: 4318

otlp_grpc:
  enabled: true
  host: 0.0.0.0
  port: 4317

metrics:
  enabled: true
  host: 0.0.0.0
  port: 9091
  path: /metrics

tracing:
  enabled: true
  service_name: icegate-ingest
  otlp_endpoint: http://jaeger:4317
  sample_ratio: 1.0
```

### OTLP Приёмники

| Параметр | Тип | По умолчанию | Описание |
|----------|-----|--------------|----------|
| `otlp_http.enabled` | bool | `true` | Включить HTTP приёмник OTLP |
| `otlp_http.host` | string | `0.0.0.0` | Адрес привязки |
| `otlp_http.port` | integer | `4318` | HTTP порт (стандарт OTLP) |
| `otlp_grpc.enabled` | bool | `true` | Включить gRPC приёмник OTLP |
| `otlp_grpc.host` | string | `0.0.0.0` | Адрес привязки |
| `otlp_grpc.port` | integer | `4317` | gRPC порт (стандарт OTLP) |

### Конфигурация Очереди (WAL)

Управляет записью входящих данных в Write-Ahead Log.

| Параметр | Тип | По умолчанию | Описание |
|----------|-----|--------------|----------|
| `queue.common.base_path` | string | — | Базовый путь для сегментов WAL (например, `s3://queue/`) |
| `queue.common.channel_capacity` | integer | `1024` | Ёмкость ограниченного канала для обратного давления |
| `queue.common.max_row_group_size` | integer | `8192` | Макс. строк в группе строк Parquet |
| `queue.write.write_retries` | integer | `5` | Количество повторных попыток записи |
| `queue.write.compression` | enum | `zstd` | Сжатие Parquet: `none`, `snappy`, `gzip`, `lzo`, `brotli`, `lz4`, `zstd` |
| `queue.write.records_per_flush_multiplier` | integer | `1` | Количество групп строк перед сбросом |
| `queue.write.max_bytes_per_flush` | integer | `67108864` | Макс. байт (64 MiB) перед сбросом |
| `queue.write.flush_interval_ms` | integer | `200` | Макс. время в мс перед сбросом |
| `queue.read.metadata_entries_cache_capacity` | integer | `2048` | Размер LRU-кэша для записей метаданных Parquet |

### Конфигурация Shift (WAL → Iceberg)

Управляет компакцией данных WAL и записью в таблицы Iceberg.

| Параметр | Тип | По умолчанию | Описание |
|----------|-----|--------------|----------|
| `shift.read.max_record_batches_per_task` | integer | `1024` | Макс. групп строк на задачу shift |
| `shift.read.max_input_bytes_per_task` | integer | `67108864` | Макс. входных байтов (64 MiB) на задачу shift |
| `shift.read.plan_segment_read_parallelism` | integer | `8` | Параллельное чтение сегментов WAL при планировании |
| `shift.read.shift_segment_read_parallelism` | integer | `8` | Параллельное чтение сегментов WAL при shift |
| `shift.write.row_group_size` | integer | `8192` | Строк в группе строк Parquet для Iceberg |
| `shift.write.max_file_size_mb` | integer | `64` | Макс. размер файла данных Iceberg в MiB |
| `shift.write.table_cache_ttl_secs` | integer | `60` | TTL для кэшированных метаданных таблиц Iceberg |
| `shift.jobsmanager.worker_count` | integer | `CPUs/2` | Количество воркеров job manager |
| `shift.jobsmanager.poll_interval_ms` | integer | `1000` | Интервал опроса для воркеров |
| `shift.jobsmanager.iteration_interval_millisecs` | integer | `30000` | Интервал между итерациями задач |

### Хранилище Job Manager

Job manager хранит состояние задач shift в отдельном бакете S3.

| Параметр | Тип | По умолчанию | Описание |
|----------|-----|--------------|----------|
| `shift.jobsmanager.storage.endpoint` | string | — | URL эндпоинта S3 |
| `shift.jobsmanager.storage.bucket` | string | — | Имя бакета для состояния задач |
| `shift.jobsmanager.storage.prefix` | string | `shifter` | Префикс ключа объекта |
| `shift.jobsmanager.storage.region` | string | `us-east-1` | Регион AWS |
| `shift.jobsmanager.storage.use_ssl` | bool | `false` | Использовать HTTPS для эндпоинта |
| `shift.jobsmanager.storage.job_state_codec` | enum | `json` | Формат сериализации: `json` или `cbor` |
| `shift.jobsmanager.storage.request_timeout_secs` | integer | `5` | Тайм-аут запроса S3 в секундах |
| `shift.jobsmanager.storage.access_key_id` | string | — | Ключ доступа S3 (запасной — переменная `AWS_ACCESS_KEY_ID`) |
| `shift.jobsmanager.storage.secret_access_key` | string | — | Секретный ключ S3 (запасной — переменная `AWS_SECRET_ACCESS_KEY`) |

## Конфигурация Сервиса Query

Полный справочник сервиса Query (`query run -c query.yaml`).

### Полный Пример

```yaml
catalog:
  backend: !rest
    uri: http://nessie:19120/iceberg
  warehouse: s3://warehouse/
  properties:
    prefix: main
  cache:
    memory_size_mb: 1024
    disk_dir: /tmp/icegate/cache
    disk_size_mb: 4096

storage:
  backend: !s3
    bucket: warehouse
    region: us-east-1
    endpoint: http://minio:9000

engine:
  batch_size: 8192
  target_partitions: 4
  catalog_name: iceberg
  refresh_interval_secs: 15
  max_age_secs: 30
  wal_query_enabled: false
  wal_metadata_size_hint: 65536

queue:
  common:
    base_path: s3://queue/

loki:
  enabled: true
  host: 0.0.0.0
  port: 3100

prometheus:
  enabled: true
  host: 0.0.0.0
  port: 9090

tempo:
  enabled: true
  host: 0.0.0.0
  port: 3200

metrics:
  enabled: true
  host: 0.0.0.0
  port: 9091
  path: /metrics

tracing:
  enabled: true
  service_name: icegate-query
  otlp_endpoint: http://jaeger:4317
  sample_ratio: 1.0
```

### Движок Запросов

| Параметр | Тип | По умолчанию | Описание |
|----------|-----|--------------|----------|
| `engine.batch_size` | integer | `8192` | Размер пакета DataFusion (строк за раз) |
| `engine.target_partitions` | integer | `4` | Параллельные партиции выполнения (установите равным числу ядер CPU) |
| `engine.catalog_name` | string | `iceberg` | Имя каталога в SQL (например, `SELECT * FROM iceberg.icegate.logs`) |
| `engine.refresh_interval_secs` | integer | `15` | Интервал фонового обновления метаданных каталога |
| `engine.max_age_secs` | integer | `30` | Макс. возраст до считания кэшированного каталога устаревшим. Должен быть >= `refresh_interval_secs` |
| `engine.wal_query_enabled` | bool | `false` | Включить данные WAL (горячие) в результаты запросов для доступа в реальном времени |
| `engine.wal_metadata_size_hint` | integer | `65536` | Байт для чтения из конца файла за один запрос для футера WAL. Установите `null` для значения DataFusion по умолчанию |

{% note info "Запросы в Реальном Времени с WAL" %}

Когда `engine.wal_query_enabled` установлен в `true`, сервис запросов читает как зафиксированные данные Iceberg, так и незафиксированные сегменты WAL. Это позволяет запрашивать данные возрастом всего несколько секунд, до того как они будут перенесены в таблицы Iceberg.

**Примечание:** Эндпоинты метаданных `/labels`, `/label/{name}/values` и `/series` всегда читают только из Iceberg, независимо от этой настройки.

{% endnote %}

### Серверы API Запросов

| Параметр | Тип | По умолчанию | Описание |
|----------|-----|--------------|----------|
| `loki.enabled` | bool | `true` | Включить Loki-совместимый API запросов логов |
| `loki.host` | string | `0.0.0.0` | Адрес привязки |
| `loki.port` | integer | `3100` | Порт Loki API |
| `prometheus.enabled` | bool | `true` | Включить Prometheus-совместимый API метрик |
| `prometheus.host` | string | `0.0.0.0` | Адрес привязки |
| `prometheus.port` | integer | `9090` | Порт Prometheus API |
| `tempo.enabled` | bool | `true` | Включить Tempo-совместимый API трейсов |
| `tempo.host` | string | `0.0.0.0` | Адрес привязки |
| `tempo.port` | integer | `3200` | Порт Tempo API |

## Конфигурация Сервиса Maintain

Сервис Maintain требует только конфигурацию каталога и хранилища:

```yaml
catalog:
  backend: !rest
    uri: http://nessie:19120/iceberg
  warehouse: s3://warehouse/
  properties:
    prefix: main

storage:
  backend: !s3
    bucket: warehouse
    region: us-east-1
    endpoint: http://minio:9000
```

### CLI Maintain

```bash
# Создать все таблицы Iceberg (первоначальная настройка)
maintain migrate create -c maintain.yaml

# Обновить схемы существующих таблиц
maintain migrate upgrade -c maintain.yaml

# Пробный запуск (показать что будет сделано)
maintain migrate create -c maintain.yaml --dry-run
maintain migrate upgrade -c maintain.yaml --dry-run
```

## Конфигурация Метрик

Все сервисы предоставляют метрики Prometheus через отдельный HTTP-сервер.

| Параметр | Тип | По умолчанию | Описание |
|----------|-----|--------------|----------|
| `metrics.enabled` | bool | `false` | Включить эндпоинт метрик Prometheus |
| `metrics.host` | string | `127.0.0.1` | Адрес привязки |
| `metrics.port` | integer | `9091` | Порт сервера метрик |
| `metrics.path` | string | `/metrics` | URL путь для метрик |

## Конфигурация Трейсинга

Все сервисы могут экспортировать трейсы OpenTelemetry для самонаблюдаемости.

| Параметр | Тип | По умолчанию | Описание |
|----------|-----|--------------|----------|
| `tracing.enabled` | bool | `true` | Включить трейсинг |
| `tracing.service_name` | string | — | Имя сервиса для трейсов |
| `tracing.otlp_endpoint` | string | — | URL эндпоинта OTLP. Запасной — переменная `OTEL_EXPORTER_OTLP_ENDPOINT` |
| `tracing.sample_ratio` | float | `1.0` | Коэффициент сэмплирования (0.0 до 1.0). Уменьшите в продакшене |

Пример с Jaeger:

```yaml
tracing:
  enabled: true
  service_name: icegate-ingest
  otlp_endpoint: http://jaeger:4317
  sample_ratio: 0.1  # Отбирать 10% трасс в продакшене
```

## Среда Разработки

Для локальной разработки используйте предоставленную конфигурацию Docker Compose:

```bash
# Запуск основных сервисов с hot-reload
make dev

# Запуск основных сервисов в release режиме
make run-core-release

# Запуск с генератором нагрузки
make run-load-release

# Запуск с мониторингом (Jaeger, Prometheus, Grafana)
make run-analytics-release
```

Переменные окружения для локальной разработки:

```bash
export AWS_ACCESS_KEY_ID=minioadmin
export AWS_SECRET_ACCESS_KEY=minioadmin
export AWS_REGION=us-east-1
```

## Следующие Шаги

- Узнайте о [Загрузке Данных](../guides/ingestion.md)
- Изучите возможности [Запросов](../guides/querying.md)
- Настройте [Мультитенантность](../guides/multi-tenancy.md)

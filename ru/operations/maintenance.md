---
title: Обслуживание
description: Обслуживание IceGate для оптимальной производительности
---

# Обслуживание

Это руководство охватывает регулярные операции обслуживания для IceGate.

## Миграция Схемы

### Первоначальная Настройка

Создание всех таблиц Iceberg при первом запуске:

```bash
maintain migrate create -c maintain.yaml
```

### Обновление Схемы

Обновление схем существующих таблиц при обновлении IceGate:

```bash
maintain migrate upgrade -c maintain.yaml
```

### Пробный Запуск

Предварительный просмотр действий без выполнения:

```bash
maintain migrate create -c maintain.yaml --dry-run
maintain migrate upgrade -c maintain.yaml --dry-run
```

### Процесс Миграции

1. Подключение к каталогу Iceberg
2. Проверка существующих схем таблиц
3. Создание отсутствующих таблиц (или изменение существующих)
4. Отчёт о статусе миграции

## Компакция Данных (Shift)

Сервис Ingest автоматически переносит данные WAL в оптимизированные таблицы Iceberg через встроенный процесс shift.

### Как Работает Shift

1. Job manager отслеживает сегменты WAL
2. Группирует сегменты в задачи shift
3. Параллельно читает Parquet файлы WAL
4. Объединяет и перепартиционирует данные
5. Записывает оптимизированные файлы данных Iceberg
6. Фиксирует новый снапшот в каталоге
7. Удаляет обработанные сегменты WAL

### Настройка Производительности Shift

Ключевые параметры конфигурации в конфигурации сервиса Ingest:

```yaml
shift:
  read:
    max_record_batches_per_task: 1024
    max_input_bytes_per_task: 67108864  # 64 MiB
    plan_segment_read_parallelism: 8
    shift_segment_read_parallelism: 8
  write:
    row_group_size: 8192
    max_file_size_mb: 64
    table_cache_ttl_secs: 60
  jobsmanager:
    worker_count: 4           # Half of available CPUs by default
    poll_interval_ms: 1000
    iteration_interval_millisecs: 30000
```

Полный справочник параметров см. в [Конфигурации](../getting-started/configuration.md#shift-wal--iceberg-configuration).

## Оптимизация Таблиц

### Оптимизация Размеров Файлов

Перезапись мелких файлов в более крупные, оптимизированные:

```sql
ALTER TABLE icegate.logs EXECUTE optimize;
```

### Истечение Снапшотов

Удаление старых снапшотов для освобождения хранилища:

```sql
ALTER TABLE icegate.logs
EXECUTE expire_snapshots(retention_threshold => '7d');
```

### Удаление Осиротевших Файлов

Удаление нессылочных файлов данных:

```sql
ALTER TABLE icegate.logs
EXECUTE remove_orphan_files(retention_threshold => '1d');
```

## Хранение Данных

### Ручное Удаление

Удаление данных старше определённой даты:

```sql
DELETE FROM icegate.logs
WHERE timestamp < TIMESTAMP '2024-01-01 00:00:00 UTC';
```

## Мониторинг

### Ключевые Метрики

Отслеживайте эти метрики для контроля здоровья обслуживания (доступны по адресу `http://ingest:9091/metrics`):

| Метрика | Описание | Порог Оповещения |
|---------|----------|------------------|
| Количество файлов WAL | Количество необработанных файлов WAL | > 1000 |
| Общий размер WAL | Общий размер WAL в байтах | > 10 GB |
| Длительность Shift | Время выполнения задачи shift | > 300s |
| Количество снапшотов | Активные снапшоты Iceberg | > 100 |

### Проверки Здоровья

```bash
# Проверка готовности сервиса query
curl http://localhost:3100/ready

# Проверка здоровья сервиса ingest
curl http://localhost:4318/health
```

## Резервное Копирование и Восстановление

### Резервное Копирование Каталога

Nessie хранит метаданные каталога. Создайте резервную копию данных RocksDB:

```bash
# Остановка Nessie
docker stop nessie

# Резервное копирование директории данных
tar -czf nessie-backup.tar.gz /data/nessie

# Перезапуск Nessie
docker start nessie
```

### Восстановление Данных

Iceberg поддерживает time-travel запросы. Для восстановления после случайного удаления:

```sql
-- Список доступных снапшотов
SELECT * FROM icegate.logs$snapshots;

-- Запрос данных на определённый снапшот
SELECT * FROM icegate.logs FOR VERSION AS OF 123456789;

-- Откат к предыдущему снапшоту
CALL icegate.system.rollback_to_snapshot('logs', 123456789);
```

### Резервное Копирование Объектного Хранилища

Включите версионирование на бакете S3 для восстановления на определённый момент времени:

```bash
aws s3api put-bucket-versioning \
  --bucket icegate-warehouse \
  --versioning-configuration Status=Enabled
```

## Настройка Производительности

### Производительность Запросов

- Убедитесь, что партиции правильно обрезаются (фильтруйте по `tenant_id`, `timestamp`)
- Мониторьте план запроса с помощью `/loki/api/v1/explain`
- Увеличьте память сервиса query для сложных агрегаций
- Включите кэш каталога для продакшен сервисов запросов

### Производительность Записи

- Масштабируйте реплики сервиса Ingest для более высокой пропускной способности
- Настройте `queue.write.flush_interval_ms` и `queue.write.max_bytes_per_flush`
- Выберите подходящий кодек сжатия (ZSTD для лучшего сжатия, Snappy для скорости)
- Мониторьте задержку записи WAL

### Производительность Компакции

- Увеличьте `shift.read.plan_segment_read_parallelism` для более быстрого чтения
- Увеличьте `shift.jobsmanager.worker_count` для большего количества параллельных задач
- Настройте `shift.jobsmanager.iteration_interval_millisecs` для более частых shift

## Следующие Шаги

- Настройте процедуры [Устранения Неполадок](troubleshooting.md)
- Проверьте конфигурацию [Развёртывания](deployment.md)
- Изучите [Модель Данных](../architecture/data-model.md)

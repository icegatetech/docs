---
title: Развёртывание
description: Развёртывание IceGate в продакшен окружениях
---

# Развёртывание

Это руководство охватывает развёртывание IceGate в продакшен окружениях.

## Предварительные Требования

- **Объектное Хранилище:** S3, MinIO или S3-совместимое хранилище
- **Каталог Iceberg:** Nessie (REST), AWS S3 Tables или AWS Glue
- **Docker/Kubernetes:** Для оркестрации контейнеров

## Архитектурные Решения

### Масштабирование Компонентов

| Компонент | Масштабирование | Примечания |
|-----------|-----------------|------------|
| Ingest | Горизонтальное | Масштабируйте для увеличения пропускной способности записи |
| Query | Горизонтальное | Масштабируйте для увеличения параллелизма запросов |
| Maintain | Один лидер | Координирует компакцию |

### Требования к Ресурсам

**Сервис Ingest (на реплику):**

- CPU: 2-4 ядра
- Память: 4-8 GB
- Диск: Минимальный (запись в объектное хранилище)

**Сервис Query (на реплику):**

- CPU: 4-8 ядер
- Память: 8-32 GB (зависит от сложности запросов)
- Диск: Рекомендуется SSD для кэша (`catalog.cache.disk_dir`)

**Сервис Maintain:**

- CPU: 2-4 ядра
- Память: 4-8 GB
- Диск: SSD для временных файлов компакции

## Развёртывание с Docker Compose

### Профили Docker Compose

Проект включает профили Docker Compose для различных сценариев развёртывания:

```bash
# Основные сервисы: MinIO, Nessie, Ingest, Query, Maintain
make run-core-release

# Основные + генератор нагрузки для тестирования
make run-load-release

# Основные + мониторинг (Jaeger, Prometheus, Grafana)
# Основные + аналитика (Trino)
make run-analytics-release
```

### Продакшен Настройка

```yaml
# docker-compose.yml
services:
  minio:
    image: minio/minio:latest
    command: server /data --console-address ":9001"
    environment:
      MINIO_ROOT_USER: ${S3_ACCESS_KEY}
      MINIO_ROOT_PASSWORD: ${S3_SECRET_KEY}
    volumes:
      - minio-data:/data
    ports:
      - "9000:9000"
      - "9001:9001"

  nessie:
    image: projectnessie/nessie:latest
    environment:
      NESSIE_VERSION_STORE_TYPE: ROCKSDB
    volumes:
      - nessie-data:/data
    ports:
      - "19120:19120"

  ingest:
    image: icegate/ingest:latest
    command: run -c /etc/icegate/ingest.yaml
    environment:
      AWS_ACCESS_KEY_ID: ${S3_ACCESS_KEY}
      AWS_SECRET_ACCESS_KEY: ${S3_SECRET_KEY}
    volumes:
      - ./config/ingest.yaml:/etc/icegate/ingest.yaml:ro
    ports:
      - "4317:4317"   # OTLP gRPC
      - "4318:4318"   # OTLP HTTP
      - "9091:9091"   # Prometheus metrics
    depends_on:
      - minio
      - nessie

  query:
    image: icegate/query:latest
    command: run -c /etc/icegate/query.yaml
    environment:
      AWS_ACCESS_KEY_ID: ${S3_ACCESS_KEY}
      AWS_SECRET_ACCESS_KEY: ${S3_SECRET_KEY}
    volumes:
      - ./config/query.yaml:/etc/icegate/query.yaml:ro
      - query-cache:/tmp/icegate/cache
    ports:
      - "3100:3100"   # Loki API
      - "9090:9090"   # Prometheus API
      - "3200:3200"   # Tempo API
    depends_on:
      - minio
      - nessie

  maintain:
    image: icegate/maintain:latest
    environment:
      AWS_ACCESS_KEY_ID: ${S3_ACCESS_KEY}
      AWS_SECRET_ACCESS_KEY: ${S3_SECRET_KEY}
    volumes:
      - ./config/maintain.yaml:/etc/icegate/maintain.yaml:ro
    depends_on:
      - minio
      - nessie

volumes:
  minio-data:
  nessie-data:
  query-cache:
```

### Сборка Docker

Сборка контейнерных образов из исходного кода:

```bash
# Сборка сервиса ingest (release режим)
docker build -t icegate/ingest:latest \
  --build-arg BINARY=ingest \
  --build-arg PROFILE=release \
  -f config/docker/Dockerfile .

# Сборка сервиса query
docker build -t icegate/query:latest \
  --build-arg BINARY=query \
  --build-arg PROFILE=release \
  -f config/docker/Dockerfile .

# Сборка сервиса maintain
docker build -t icegate/maintain:latest \
  --build-arg BINARY=maintain \
  --build-arg PROFILE=release \
  -f config/docker/Dockerfile .
```

## Развёртывание в Kubernetes

### Helm Charts

IceGate включает Helm charts для развёртывания в Kubernetes:

```bash
# Установка из локальных charts
helm install icegate ./config/helm/icegate

# С пользовательскими значениями
helm install icegate ./config/helm/icegate \
  -f my-values.yaml \
  --set storage.bucket=my-warehouse
```

### Kustomize Overlays

Доступны готовые Kustomize overlays для распространённых сценариев:

| Overlay | Описание |
|---------|----------|
| `skaffold` | Локальная разработка со Skaffold |
| `orbstack` | Среда выполнения контейнеров OrbStack |
| `aws-glue` | Интеграция с каталогом AWS Glue |
| `external-s3` | Внешнее хранилище S3 (не MinIO) |

```bash
# Применение с kustomize
kubectl apply -k config/kustomize/overlays/aws-glue
```

## Конфигурация Хранилища S3

### AWS S3

```yaml
storage:
  backend: !s3
    bucket: icegate-warehouse
    region: us-east-1
```

### MinIO

```yaml
storage:
  backend: !s3
    bucket: warehouse
    endpoint: http://minio:9000
    region: us-east-1
```

## Высокая Доступность

### Мультизонное Развёртывание

Развёртывание сервисов в нескольких зонах доступности:

```yaml
services:
  query:
    deploy:
      replicas: 3
      placement:
        constraints:
          - node.labels.zone != ${ZONE}
```

### Проверки Здоровья

Все сервисы предоставляют эндпоинты проверки здоровья:

- Ingest: `GET /health` (порт 4318)
- Query: `GET /ready` (порт 3100)

## Мониторинг

### Метрики

Сервисы IceGate предоставляют метрики Prometheus на выделенном порту (по умолчанию: 9091):

- Метрики Ingest: `http://ingest:9091/metrics`
- Метрики Query: `http://query:9091/metrics`

Настройка в каждом сервисе:

```yaml
metrics:
  enabled: true
  host: 0.0.0.0
  port: 9091
  path: /metrics
```

### Самонаблюдаемость с Трейсингом

IceGate может экспортировать собственные трейсы через OTLP для отладки:

```yaml
tracing:
  enabled: true
  service_name: icegate-query
  otlp_endpoint: http://jaeger:4317
  sample_ratio: 0.1  # 10% sampling in production
```

### Логирование

Сервисы пишут логи в stdout. Настройте уровень логирования через переменную окружения `RUST_LOG`:

```yaml
environment:
  RUST_LOG: "info,icegate_query=debug"
```

## Безопасность

### Сетевая Безопасность

- Используйте TLS для всех внешних подключений
- Ограничьте доступ к MinIO/Nessie только внутренней сетью
- Используйте сетевые политики в Kubernetes

### Аутентификация

Настройте аутентификацию тенантов через обратный прокси или API gateway:

```nginx
location /loki/ {
    auth_request /auth;
    proxy_set_header X-Scope-OrgID $remote_user;
    proxy_pass http://query:3100/;
}
```

## Следующие Шаги

- Настройте операции [Обслуживания](maintenance.md)
- Настройте процедуры [Устранения Неполадок](troubleshooting.md)
- Изучите [Архитектуру](../architecture/overview.md) для принятия решений по масштабированию

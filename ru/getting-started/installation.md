---
title: Установка
description: Установка {{product_name}} в Kubernetes с помощью Helm
---

# Установка

{{product_name}} разворачивается в Kubernetes с помощью Helm charts и оверлеев Kustomize для настройки под конкретное окружение.

## Предварительные Требования

- **Kubernetes** >= 1.28 с **Helm 3**
- **Объектное хранилище:** AWS S3 или S3-совместимое (RustFS)
- **Каталог Iceberg:** встроенный S3-каталог (по умолчанию, без внешнего сервиса), либо Nessie (REST), AWS S3 Tables или AWS Glue

## Helm Chart

Helm chart разворачивает все компоненты {{product_name}}: Ingest, Query и задачу Migrate (создание схемы в виде хука pre-install/pre-upgrade).

### Установка из реестра OCI

```bash
helm install icegate oci://ghcr.io/icegatetech/charts/icegate \
  --version 0.1.0 \
  --namespace icegate \
  --create-namespace \
  -f values.yaml
```

### Установка из локальных чартов

```bash
git clone https://github.com/icegatetech/icegate.git
helm install icegate ./icegate/config/helm/icegate \
  --namespace icegate \
  --create-namespace \
  -f values.yaml
```

### Минимальный values.yaml

{% note info %}

Значения Helm используют camelCase и плоские ключи (например, `backend: rest` + `rest.uri`). Chart транслирует их в нативный формат конфигурации serde tagged enum (`backend: !rest`), который ожидают бинарные файлы IceGate. См. [Конфигурацию](configuration.md) для справочника по нативному формату конфигурации.

{% endnote %}

Минимальный файл `values.yaml` для REST-каталога (Nessie) с S3-совместимым хранилищем:

```yaml
catalog:
  backend: rest
  rest:
    uri: http://nessie:19120/iceberg
  warehouse: "s3://warehouse/"

storage:
  s3:
    bucket: warehouse
    region: us-east-1
    endpoint: "http://rustfs:9000"

queue:
  common:
    basePath: "s3://queue/"

aws:
  existingSecret: icegate-aws-credentials
  region: us-east-1
```

### Каталог AWS Glue

```yaml
catalog:
  backend: glue
  glue:
    catalogId: "123456789012"
  warehouse: "s3://my-bucket/warehouse/"

storage:
  s3:
    bucket: my-bucket
    region: eu-central-1

aws:
  existingSecret: icegate-aws-credentials
  region: eu-central-1
```

### Каталог AWS S3 Tables

```yaml
catalog:
  backend: s3tables
  s3tables:
    tableBucketArn: "arn:aws:s3tables:eu-central-1:123456789012:bucket/my-tables"

storage:
  s3:
    region: eu-central-1

aws:
  existingSecret: icegate-aws-credentials
  region: eu-central-1
```

### Основные значения Helm

| Значение | По умолчанию | Описание |
|----------|--------------|----------|
| `catalog.backend` | `s3` | Тип каталога: `s3`, `rest`, `s3tables` или `glue` |
| `storage.s3.bucket` | `warehouse` | Имя S3-бакета |
| `storage.s3.endpoint` | `""` | Пользовательский S3-эндпоинт (RustFS). Опустить для реального AWS S3 |
| `aws.existingSecret` | `""` | Secret с ключами `aws-access-key-id` и `aws-secret-access-key` |
| `query.replicaCount` | `1` | Количество реплик сервиса Query |
| `ingest.replicaCount` | `1` | Количество реплик сервиса Ingest |
| `query.cache.enabled` | `true` | Включить гибридный кеш диск+память для чтения запросов |
| `query.engine.walQueryEnabled` | `false` | Включить данные WAL в результаты запросов для доступа в реальном времени |
| `serviceMonitor.enabled` | `false` | Создать ресурсы Prometheus ServiceMonitor |
| `migrate.enabled` | `true` | Запустить миграцию схемы как хук Helm |

### Образы контейнеров

| Компонент | Образ |
|-----------|-------|
| Query | `ghcr.io/icegatetech/icegate-query` |
| Ingest | `ghcr.io/icegatetech/icegate-ingest` |
| Migrate | `ghcr.io/icegatetech/icegate-maintain` |

## Оверлеи Kustomize

Для настройки под конкретное окружение {{product_name}} предоставляет оверлеи Kustomize, которые компонуют Helm chart с зависимостями инфраструктуры.

### Доступные оверлеи

| Оверлей | Описание | Инфраструктура |
|---------|----------|----------------|
| `skaffold` | Локальная разработка со Skaffold | RustFS, стек наблюдаемости |
| `orbstack` | Среда выполнения контейнеров OrbStack | RustFS, стек наблюдаемости |
| `aws-glue` | Каталог AWS Glue | Стек наблюдаемости (внешний S3) |
| `aws-s3tables` | Каталог AWS S3 Tables | Стек наблюдаемости (внешний S3) |
| `external-s3` | Внешний S3 + каталог Nessie | Nessie, стек наблюдаемости |

Все оверлеи используют общую базу (`config/kustomize/base/`), которая разворачивает стек наблюдаемости: Prometheus (kube-prometheus-stack), Grafana с готовыми дашбордами {{product_name}} и Jaeger для распределённой трассировки.

### Использование

```bash
# Применить оверлей напрямую
kubectl apply -k config/kustomize/overlays/aws-glue

# Или используйте Skaffold для разработки (см. Окружение для Разработки)
skaffold dev
```

### Настройка оверлея

Каждый оверлей содержит:

- `kustomization.yaml` — объявляет Helm charts и патчи
- `values-icegate.yaml` — значения Helm {{product_name}} для данного окружения
- `secret-aws.yaml` — Secret с учётными данными AWS (отредактировать перед применением)

Для создания пользовательского оверлея:

```bash
cp -r config/kustomize/overlays/orbstack config/kustomize/overlays/my-env
vi config/kustomize/overlays/my-env/values-icegate.yaml
vi config/kustomize/overlays/my-env/secret-aws.yaml
kubectl apply -k config/kustomize/overlays/my-env
```

## Проверка Установки

```bash
# Проверить, что поды запущены
kubectl get pods -n icegate

# Перенаправить порт к сервису Query
kubectl port-forward -n icegate svc/icegate-query 3100:3100

# Проверить готовность
curl http://localhost:3100/ready
```

## Следующие Шаги

- Перейдите к [Быстрому старту](quickstart.md) для загрузки первых данных
- Смотрите [Конфигурацию](configuration.md) для подробных настроек
- Настройте [Окружение для разработки](../development/setup.md) для участия в проекте

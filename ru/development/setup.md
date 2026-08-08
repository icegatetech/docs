---
title: Окружение для Разработки
description: Настройка локального окружения для разработки {{product_name}}
---

# Окружение для Разработки

Это руководство описывает настройку локального окружения для разработки {{product_name}}: написания кода, запуска тестов и отладки.

## Предварительные Требования

- **Rust** >= {{rust_version}} (Rust 2024 edition)
- **Docker** (для сборки контейнерных образов)
- **Git**
- Локальный кластер Kubernetes (для Skaffold)

### Установка Rust

```bash
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
source $HOME/.cargo/env
rustc --version  # Должна быть >= 1.92.0
```

### Клонирование Репозитория

```bash
git clone https://github.com/icegatetech/icegate.git
cd icegate
```

## Skaffold (Рекомендуется)

[Skaffold](https://skaffold.dev/) — рекомендуемый способ разработки IceGate. Он собирает образы из исходного кода, разворачивает их в локальном кластере Kubernetes и отслеживает изменения файлов для автоматической пересборки.

### Установка Skaffold

```bash
# macOS
brew install skaffold

# Linux
curl -Lo skaffold https://storage.googleapis.com/skaffold/releases/latest/skaffold-linux-amd64
chmod +x skaffold && sudo mv skaffold /usr/local/bin/
```

### Локальный Кластер Kubernetes

Вам понадобится локальный кластер Kubernetes. Варианты:

| Среда выполнения | Установка | Примечания |
|------------------|-----------|------------|
| [OrbStack](https://orbstack.dev/) | только macOS | Легковесный, быстрый запуск. Используйте профиль `-p orbstack` |
| [Docker Desktop](https://docs.docker.com/desktop/kubernetes/) | macOS, Windows, Linux | Включите Kubernetes в настройках |
| [minikube](https://minikube.sigs.k8s.io/) | Все платформы | `minikube start` |
| [kind](https://kind.sigs.k8s.io/) | Все платформы | `kind create cluster` |

### Запуск со Skaffold

```bash
# Профиль по умолчанию (локальный k8s с RustFS + встроенным S3-каталогом)
skaffold dev

# Профиль OrbStack
skaffold dev -p orbstack

# Профиль AWS Glue (отправляет образы в реестр)
skaffold dev -p aws-glue

# Профиль External S3
skaffold dev -p k3s-external-s3
```

### Что Разворачивает Skaffold

Skaffold использует оверлеи Kustomize, которые компонуют несколько Helm charts:

**Пространство имён {{product_name}} (`icegate`):**

| Компонент | Описание |
|-----------|----------|
| `icegate-ingest` | Приёмники OTLP (gRPC 4317, HTTP 4318) + процесс shift |
| `icegate-query` | API запросов (Loki 3100, Prometheus 9090, Tempo 3200) |
| `icegate-migrate` | Задача создания схемы (хук Helm pre-install) |

**Пространство имён инфраструктуры (`infra`):**

| Компонент | Описание |
|-----------|----------|
| RustFS | S3-совместимое хранилище с бакетами: `warehouse`, `queue`, `jobs` |

**Пространство имён наблюдаемости (`observability`):**

| Компонент | Описание |
|-----------|----------|
| Prometheus | Сбор метрик (kube-prometheus-stack) |
| Grafana | Дашборды с готовыми панелями {{product_name}} Ingest и Query |
| Jaeger | Распределённая трассировка для сервисов {{product_name}} |

### Профили Skaffold

| Профиль | Оверлей | Назначение |
|---------|---------|------------|
| (по умолчанию) | `skaffold` | Локальная разработка с RustFS + встроенным S3-каталогом |
| `orbstack` | `orbstack` | OrbStack Kubernetes (macOS) |
| `aws-glue` | `aws-glue` | Каталог AWS Glue (отправляет образы) |
| `k3s-external-s3` | `external-s3` | Внешний S3 + Nessie (отправляет образы) |

### Доступ к Сервисам

```bash
# Перенаправление портов сервисов IceGate
kubectl port-forward -n icegate svc/icegate-query 3100:3100 &
kubectl port-forward -n icegate svc/icegate-ingest 4318:4318 4317:4317 &

# Перенаправление портов наблюдаемости
kubectl port-forward -n observability svc/grafana 3000:80 &
kubectl port-forward -n observability svc/jaeger-query 16686:16686 &
```

### Изменение Кода

Skaffold отслеживает директорию `crates/` и автоматически пересобирает образы при изменении файлов. Цикл пересборки и развёртывания занимает около 1-2 минут для release-сборки.

Для более быстрой итерации над конкретным сервисом без пересборки образов можно собрать проект локально через `cargo build` и запустить бинарный файл напрямую с конфигурационным файлом (см. [Сборка из исходного кода](building.md)).

## Docker Compose (Альтернатива)

Docker Compose доступен как более простая альтернатива, не требующая Kubernetes.

### Запуск Стека Разработки

```bash
# Основные сервисы с hot-reload (debug-сборка)
make dev

# Основные сервисы в release-режиме
make run-core-release

# С генератором нагрузки
make run-load-release

# С мониторингом (Jaeger, Prometheus)
make run-monitoring-release

# С аналитикой (Trino SQL)
make run-analytics-release

# Остановить все сервисы
make down
```

### Сервисы Docker Compose

| Сервис | Порт | Описание |
|--------|------|----------|
| RustFS | 9000, 9001 | S3-совместимое хранилище + консоль |
| Ingest | 4317, 4318 | Приёмники OTLP gRPC и HTTP |
| Query | 3100, 9090, 3200, 8815 | API Loki, Prometheus, Tempo, Arrow Flight SQL |
| Grafana | 3000 | Дашборды |

Профили Docker Compose добавляют дополнительные сервисы:

| Профиль | Сервисы |
|---------|---------|
| `load` | otelgen (генератор нагрузки логов) |
| `monitoring` | Jaeger (16686), Prometheus (9092), node-exporter, cAdvisor |
| `analytics` | Nessie (19120) и SQL-движок Trino (8082) |

### Сборка Docker

Сборка отдельных контейнерных образов:

```bash
# Используя release Dockerfile (мульти-архитектурный, с кешем cargo-chef)
docker build -t icegate/query:latest \
  --build-arg BINARY=query \
  -f config/docker/release.Dockerfile .

# Используя dev Dockerfile (проще, одна архитектура)
docker build -t icegate/query:dev \
  --build-arg BINARY=query \
  --build-arg PROFILE=debug \
  -f config/docker/Dockerfile .
```

## Переменные Окружения

Для локальной разработки с RustFS:

```bash
export AWS_ACCESS_KEY_ID=rustfsadmin
export AWS_SECRET_ACCESS_KEY=rustfsadmin
export AWS_REGION=us-east-1
```

## Следующие Шаги

- Узнайте, как [Собрать из исходного кода](building.md) и запустить отдельные сервисы
- Прочитайте о [Паттернах разработки](patterns.md) для соглашений по написанию кода
- Смотрите [Участие в проекте](contributing.md) для рекомендаций по PR

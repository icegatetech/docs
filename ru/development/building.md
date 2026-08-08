---
title: Сборка
description: Сборка {{product_name}} из исходного кода
---

# Сборка из Исходного Кода

Это руководство охватывает сборку {{product_name}} из исходного кода для разработки и продакшена.

## Предварительные Требования

### Обязательные

- **Rust** >= {{rust_version}} (для поддержки Rust 2024 edition)
- **Cargo** (входит в Rust)
- **Git**

### Опциональные

- **Java** (для регенерации ANTLR парсера)
- **Docker** (для среды разработки)
- **protoc** (для регенерации protobuf кода)

## Установка Rust

```bash
# Установка через rustup
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh

# Проверка установки
rustc --version
cargo --version
```

## Клонирование Репозитория

```bash
git clone https://github.com/icegatetech/icegate.git
cd icegate
```

## Сборка

### Debug Сборка

```bash
cargo build
```

Артефакты сборки в `target/debug/`.

### Release Сборка

```bash
cargo build --release
```

Артефакты сборки в `target/release/`.

### Конкретные Бинарные Файлы

```bash
# Только сервис Query
cargo build --bin query

# Только сервис Ingest
cargo build --bin ingest

# Только сервис Maintain
cargo build --bin maintain
```

## Профили Сборки

| Профиль | Команда | Назначение |
|---------|---------|------------|
| dev | `cargo build` | Разработка, отладка |
| release | `cargo build --release` | Продакшен |
| test | `cargo test` | Запуск тестов |
| bench | `cargo bench` | Бенчмарки |

### Конфигурация Профилей

Пользовательские профили в `Cargo.toml`:

```toml
[profile.release]
opt-level = 3
lto = true
codegen-units = 1

[profile.dev]
opt-level = 0
debug = true
```

## Структура Рабочего Пространства

{{product_name}} использует Cargo workspace:

```text
Cargo.toml (workspace)
├── crates/
│   ├── icegate-common/Cargo.toml
│   ├── icegate-catalog-s3/Cargo.toml
│   ├── icegate-queue/Cargo.toml
│   ├── icegate-query/Cargo.toml
│   ├── icegate-ingest/Cargo.toml
│   └── icegate-maintain/Cargo.toml
```

Сборка отдельных крейтов:

```bash
cargo build -p icegate-query
cargo build -p icegate-common
```

## Запуск Сервисов

### Сервис Query

```bash
cargo run --bin query -- run -c config/docker/query.yaml
```

### Сервис Ingest

```bash
cargo run --bin ingest -- run -c config/docker/ingest.yaml
```

### Сервис Maintain

```bash
cargo run --bin maintain -- migrate create -c config/docker/maintain.yaml
```

## Регенерация Парсера LogQL

Парсер LogQL генерируется из файлов грамматики ANTLR4.

### Предварительные Требования

- Java JDK 11+

### Генерация Парсера

```bash
cd crates/icegate-query/src/logql

# Установка ANTLR jar (первый раз)
make install

# Регенерация парсера из .g4 файлов
make gen
```

Файлы грамматики находятся в `crates/icegate-query/src/logql/antlr/`.

## Запуск Тестов

```bash
# Все тесты
cargo test

# Конкретный тест
cargo test test_name

# С выводом
cargo test -- --nocapture

# В release режиме (быстрее, но дольше собирается)
cargo test --release
```

## Качество Кода

```bash
# Проверка форматирования
make fmt

# Линтинг
make clippy

# Аудит безопасности
make audit

# Все проверки CI
make ci
```

## Устранение Проблем Сборки

### Ошибки Компиляции

1. Убедитесь, что версия Rust >= {{rust_version}}:

   ```bash
   rustup update
   ```

2. Очистите артефакты сборки:

   ```bash
   cargo clean
   cargo build
   ```

### Ошибки Линковки

Некоторые зависимости требуют системных библиотек:

**macOS:**

```bash
brew install openssl
```

**Ubuntu/Debian:**

```bash
apt install libssl-dev pkg-config
```

### Нехватка Памяти

Крупные кодовые базы могут требовать больше памяти:

```bash
# Уменьшение параллелизма
cargo build -j 2
```

## Сборка Docker

Сборка контейнерных образов:

```bash
# Release-сборка (мульти-архитектурная, с кешем cargo-chef)
docker build -t icegate/query:latest \
  --build-arg BINARY=query \
  -f config/docker/release.Dockerfile .

# Dev-сборка (проще, одна архитектура)
docker build -t icegate/query:dev \
  --build-arg BINARY=query \
  --build-arg PROFILE=debug \
  -f config/docker/Dockerfile .
```

## Следующие Шаги

- Настройте [Окружение для разработки](setup.md) со Skaffold или Docker Compose
- Изучите [Паттерны разработки](patterns.md)
- Начните [Участвовать](contributing.md)

---
title: Участие в Проекте
description: Как участвовать в разработке {{product_name}}
---

# Участие в Проекте

{% note warning %}

Эта страница находится в процессе перевода. Полную документацию смотрите в английской версии.

{% endnote %}

Мы приветствуем участие в {{product_name}}! Это руководство объясняет как начать.

## Способы Участия

- **Сообщать о багах** через GitHub Issues
- **Предлагать функции** через GitHub Issues
- **Отправлять pull requests**
- **Улучшать документацию**

## Настройка Разработки

```bash
# Клонировать репозиторий
git clone https://github.com/icegatetech/icegate.git
cd icegate

# Собрать проект
cargo build

# Запустить тесты
cargo test
```

### Запуск Среды Разработки

```bash
# Рекомендуется: Skaffold с локальным Kubernetes
skaffold dev

# Альтернатива: Docker Compose с hot-reload
make dev
```

Подробности о профилях Skaffold и вариантах Docker Compose смотрите в [Окружении для разработки](setup.md).

## CI Проверки

```bash
make ci
```

## Следующие Шаги

- Изучите [Сборку](building.md)
- Поймите [Паттерны разработки](patterns.md)

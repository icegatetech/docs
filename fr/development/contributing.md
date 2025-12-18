---
title: Contribuer
description: Comment contribuer au développement d'IceGate
---

# Contribuer

{% note warning %}

Cette page est en cours de traduction. Pour la documentation complète, veuillez consulter la version anglaise.

{% endnote %}

Nous accueillons les contributions à IceGate ! Ce guide explique comment commencer.

## Façons de Contribuer

- **Signaler des bugs** via GitHub Issues
- **Demander des fonctionnalités** via GitHub Issues
- **Soumettre des pull requests**
- **Améliorer la documentation**

## Configuration du Développement

```bash
# Cloner le dépôt
git clone https://github.com/icegatetech/icegate.git
cd icegate

# Compiler le projet
cargo build

# Exécuter les tests
cargo test
```

## Vérifications CI

```bash
make ci
```

## Étapes Suivantes

- Revoir la [Compilation](building.md)
- Comprendre les [Patterns de Développement](patterns.md)

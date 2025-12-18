# AGENTS.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

IceGate documentation site built with [Diplodoc](https://diplodoc.com/) (YFM - Yandex Flavored Markdown). Multi-language documentation (en, fr, ru) for an Observability Data Lake engine.

## Commands

```bash
npm run build      # Build all languages to ./build
npm run lint       # Lint docs with --strict mode
npm run serve      # Build and serve locally on port 8080
npm run clean      # Remove build directory
```

Language-specific builds:
```bash
npm run build:en   # Build English only
npm run build:fr   # Build French only
npm run build:ru   # Build Russian only
```

## Project Structure

```
├── en/            # English documentation
├── fr/            # French documentation
├── ru/            # Russian documentation
├── presets.yaml   # Build presets (default, development, production)
├── .yfm           # Diplodoc configuration (vars, langs, settings)
└── .yfmlint       # Linter rules configuration
```

Each language directory has identical structure:
- `index.yaml` - Landing page configuration
- `toc.yaml` - Table of contents and navigation
- `getting-started/`, `guides/`, `api-reference/`, etc. - Content sections

## Configuration Files

- **`.yfm`** - Main config: variables (`{{product_name}}`), language settings, markdown options
- **`presets.yaml`** - Variable presets for different build environments
- **`.yfmlint`** - Markdown/YFM linting rules (MD* for markdownlint, YFM* for Diplodoc)

## Writing Documentation

- Use variables from `.yfm` vars section: `{{product_name}}`, `{{version}}`, `{{repo_url}}`
- HTML is allowed (`allowHTML: true`)
- Files must end with newline (MD047 enforced)
- Line length not enforced (MD013 disabled)

## Deployment

GitHub Pages deployment via Actions (`.github/workflows/deploy-pages.yml`) triggers on push to `main`.
PR lint checks run via `.github/workflows/lint.yml`.

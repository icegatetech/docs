# IceGate Documentation

Documentation site for [IceGate](https://github.com/icegatetech/icegate) - an Observability Data Lake Engine.

Built with [Diplodoc](https://diplodoc.com/) (YFM - Yandex Flavored Markdown).

## Quick Start

```bash
# Install dependencies
npm install

# Build and serve locally
npm run serve
# Open http://localhost:8080
```

## Commands

| Command | Description |
|---------|-------------|
| `npm run build` | Build all languages to `./build` |
| `npm run build:en` | Build English only |
| `npm run build:fr` | Build French only |
| `npm run build:ru` | Build Russian only |
| `npm run serve` | Build and serve locally on port 8080 |
| `npm run lint` | Lint docs with `--strict` mode |
| `npm run clean` | Remove build directory |

## Project Structure

```
├── en/                 # English documentation
├── fr/                 # French documentation
├── ru/                 # Russian documentation
├── assets/             # Shared assets (images, diagrams)
│   └── c4/             # C4 architecture diagrams
├── c4/                 # C4 model source (Structurizr DSL)
├── .yfm                # Diplodoc configuration
├── .yfmlint            # Linter rules
└── presets.yaml        # Build presets
```

## Languages

Documentation is available in:
- **English** (`en/`) - Primary language
- **French** (`fr/`) - Partial translation
- **Russian** (`ru/`) - Partial translation

## Architecture Diagrams

C4 model diagrams are maintained in the [`c4/`](c4/README.md) directory using Structurizr DSL.

See [c4/README.md](c4/README.md) for:
- Generating diagrams
- Editing the architecture model
- Available diagram types

## Configuration

- **`.yfm`** - Main config: variables, language settings, markdown options
- **`presets.yaml`** - Variable presets for different build environments
- **`.yfmlint`** - Markdown/YFM linting rules

## Deployment

Deployed to GitHub Pages via GitHub Actions on push to `main`.

- **Production**: https://icegatetech.github.io/docs/
- **Workflow**: `.github/workflows/deploy-pages.yml`

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## License

This documentation is licensed under [CC BY 4.0](LICENSE).
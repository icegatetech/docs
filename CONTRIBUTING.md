# Contributing to IceGate Documentation

Thank you for your interest in contributing to IceGate documentation.

## Getting Started

1. Fork and clone the repository
2. Install dependencies: `npm install`
3. Create a feature branch: `git checkout -b feature/my-contribution`

## Development Workflow

```bash
# Build and serve locally
npm run serve
# Open http://localhost:8080

# Validate changes
npm run lint
```

## Writing Documentation

### File Structure

Each language directory follows the same structure:

```
en/
├── index.yaml              # Landing page
├── toc.yaml                # Table of contents
├── getting-started/        # Getting started guides
├── guides/                 # How-to guides
├── api-reference/          # API documentation
├── architecture/           # Architecture docs
├── operations/             # Operations guides
├── development/            # Development docs
└── faq.md                  # FAQ
```

### Markdown Guidelines

- Use [Diplodoc](https://diplodoc.com/) (YFM) syntax
- Variables are defined in `.yfm`: `{{product_name}}`, `{{version}}`
- End files with a newline (enforced by linter)
- Use ATX-style headers (`#`, `##`, `###`)

### Adding New Pages

1. Create the `.md` file in the appropriate directory
2. Add the page to `toc.yaml` in the corresponding language
3. Add to all language versions (can be a stub with translation notice)

### Translation Guidelines

For incomplete translations, add a notice at the top:

```markdown
{% note warning %}

This page is being translated. For complete documentation, see the English version.

{% endnote %}
```

## Architecture Diagrams

C4 diagrams are maintained in `c4/` using Structurizr DSL.

```bash
cd c4

# Generate diagrams
make png

# Edit interactively
make lite
```

See [c4/README.md](c4/README.md) for details.

## Pull Request Process

1. Ensure `npm run lint` passes
2. Update all language versions if adding new pages
3. Add meaningful commit messages
4. Submit PR against `main` branch

## Code of Conduct

Be respectful and constructive in all interactions.

## License

By contributing, you agree that your contributions will be licensed under CC BY 4.0.
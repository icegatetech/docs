# IceGate C4 Architecture Diagrams
# Uses structurizr-cli: brew install structurizr-cli
# Uses plantuml: brew install plantuml

WORKSPACE := workspace.dsl
ASSETS_DIR := ../assets/c4
PUML_DIR := _puml

.PHONY: all png svg validate lite serve clean help check check-plantuml plantuml

help:
	@echo "IceGate C4 Architecture Diagrams"
	@echo ""
	@echo "Prerequisites:"
	@echo "  brew install structurizr-cli plantuml"
	@echo "  docker (for Structurizr Lite)"
	@echo ""
	@echo "Generate Diagrams:"
	@echo "  make png       - Export diagrams as PNG to $(ASSETS_DIR)"
	@echo "  make svg       - Export diagrams as SVG to $(ASSETS_DIR)"
	@echo ""
	@echo "Interactive UI:"
	@echo "  make lite      - Run Structurizr Lite at http://localhost:8080"
	@echo "  make serve     - Export HTML and serve at http://localhost:8000"
	@echo ""
	@echo "Utilities:"
	@echo "  make validate  - Validate workspace DSL"
	@echo "  make plantuml  - Export PlantUML files only"
	@echo "  make clean     - Remove generated files"

check:
	@command -v structurizr-cli >/dev/null 2>&1 || { \
		echo "Error: structurizr-cli not found."; \
		echo "Install with: brew install structurizr-cli"; \
		exit 1; \
	}

check-plantuml:
	@command -v plantuml >/dev/null 2>&1 || { \
		echo "Error: plantuml not found."; \
		echo "Install with: brew install plantuml"; \
		exit 1; \
	}

$(ASSETS_DIR):
	mkdir -p $(ASSETS_DIR)

$(PUML_DIR):
	mkdir -p $(PUML_DIR)

plantuml: check $(PUML_DIR)
	structurizr-cli export -workspace $(WORKSPACE) -format plantuml/c4plantuml -output $(PUML_DIR)
	@echo "PlantUML files exported to $(PUML_DIR)/"

png: check check-plantuml $(ASSETS_DIR) $(PUML_DIR)
	structurizr-cli export -workspace $(WORKSPACE) -format plantuml/c4plantuml -output $(PUML_DIR)
	plantuml -tpng -o "$(shell pwd)/$(ASSETS_DIR)" $(PUML_DIR)/*.puml
	@echo ""
	@echo "PNG diagrams exported to $(ASSETS_DIR)/"
	@ls -la $(ASSETS_DIR)/*.png 2>/dev/null || true

svg: check check-plantuml $(ASSETS_DIR) $(PUML_DIR)
	structurizr-cli export -workspace $(WORKSPACE) -format plantuml/c4plantuml -output $(PUML_DIR)
	plantuml -tsvg -o "$(shell pwd)/$(ASSETS_DIR)" $(PUML_DIR)/*.puml
	@echo ""
	@echo "SVG diagrams exported to $(ASSETS_DIR)/"
	@ls -la $(ASSETS_DIR)/*.svg 2>/dev/null || true

validate: check
	@echo "Validating workspace..."
	@structurizr-cli validate -workspace $(WORKSPACE) && echo "✓ Workspace is valid"

lite:
	@command -v docker >/dev/null 2>&1 || { \
		echo "Error: docker not found. Install Docker Desktop first."; \
		exit 1; \
	}
	@echo "Starting Structurizr Lite..."
	@echo "Open http://localhost:8080 in your browser"
	@echo "Press Ctrl+C to stop"
	@docker run -it --rm -p 8080:8080 -v "$$(pwd):/usr/local/structurizr" structurizr/lite

serve: check
	@mkdir -p _site
	structurizr-cli export -workspace $(WORKSPACE) -format static -output _site
	@echo "Starting local server at http://localhost:8000"
	@cd _site && python3 -m http.server 8000

all: png svg

clean:
	rm -rf $(PUML_DIR) $(ASSETS_DIR)/*.png $(ASSETS_DIR)/*.svg _site

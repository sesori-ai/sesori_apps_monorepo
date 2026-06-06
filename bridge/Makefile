TOOL_VERSIONS := $(shell git rev-parse --show-toplevel)/.tool-versions
FLUTTER_VERSION := $(shell grep '^flutter' $(TOOL_VERSIONS) | awk '{print $$2}')
DART := $(HOME)/.asdf/installs/flutter/$(FLUTTER_VERSION)/bin/cache/dart-sdk/bin/dart

MODULES := sesori_plugin_interface sesori_plugin_opencode app

# Path to the OpenCode OpenAPI spec. Override on the command line:
#   make codegen OPENCODE_SPEC=/path/to/openapi.json
OPENCODE_SPEC ?= /Users/alexandrudochioiu/sesori-ai/opencode/packages/sdk/openapi.json

.PHONY: codegen opencode-codegen pub-get test analyze

# Regenerates the OpenCode v2 REST client, model classes, and SSE event
# sealed-class hierarchy. Reads `tool/opencode_events_v1.json` (a hand-
# curated v1 SSE event manifest) and the OpenAPI spec at $(OPENCODE_SPEC).
opencode-codegen:
	(cd sesori_plugin_opencode && $(DART) run tool/generate_opencode_client.dart $(OPENCODE_SPEC))
	(cd sesori_plugin_opencode && $(DART) run tool/generate_sse_events.dart)

codegen: opencode-codegen
	@for mod in $(MODULES); do \
		echo "=== codegen: $$mod ==="; \
		(cd $$mod && $(DART) run build_runner build --delete-conflicting-outputs); \
	done

pub-get:
	$(DART) pub get

test:
	@for mod in $(MODULES); do \
		if [ -d "$$mod/test" ]; then \
			echo "=== test: $$mod ==="; \
			(cd $$mod && $(DART) test) || exit 1; \
		fi; \
	done

analyze:
	@for mod in $(MODULES); do \
		echo "=== analyze: $$mod ==="; \
		(cd $$mod && $(DART) analyze) || exit 1; \
	done

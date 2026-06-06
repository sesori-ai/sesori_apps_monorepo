TOOL_VERSIONS := $(shell git rev-parse --show-toplevel)/.tool-versions
FLUTTER_VERSION := $(shell grep '^flutter' $(TOOL_VERSIONS) | awk '{print $$2}')
DART := $(HOME)/.asdf/installs/flutter/$(FLUTTER_VERSION)/bin/cache/dart-sdk/bin/dart

MODULES := sesori_plugin_interface sesori_plugin_opencode app

.PHONY: codegen opencode-codegen pub-get test analyze

# Regenerates the OpenCode v2 REST client, model classes, and SSE event
# sealed-class hierarchy. OPT-IN: not a dependency of the regular `codegen`
# target, because the OpenAPI spec is maintained in a sibling repo
# (https://github.com/ssesori/opencode) that may not be present on every
# developer's machine. Run explicitly when you want to refresh the v2
# generated code:
#
#   make opencode-codegen OPENCODE_SPEC=/path/to/openapi.json
#
# Reads `tool/opencode_events_v1.json` (hand-curated v1 SSE event manifest)
# and the OpenAPI spec at $(OPENCODE_SPEC).
OPENCODE_SPEC ?= openapi.json
opencode-codegen:
	@if [ ! -f "$(OPENCODE_SPEC)" ]; then \
		echo "error: OpenAPI spec not found at $(OPENCODE_SPEC)"; \
		echo "  pass an absolute path: make opencode-codegen OPENCODE_SPEC=/path/to/openapi.json"; \
		exit 1; \
	fi
	(cd sesori_plugin_opencode && $(DART) run tool/generate_opencode_client.dart $(OPENCODE_SPEC))
	(cd sesori_plugin_opencode && $(DART) run tool/generate_sse_events.dart)

codegen:
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

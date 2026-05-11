TOOL_VERSIONS := $(shell git rev-parse --show-toplevel)/.tool-versions
FLUTTER_VERSION := $(shell grep '^flutter' $(TOOL_VERSIONS) | awk '{print $$2}')
DART := $(HOME)/.asdf/installs/flutter/$(FLUTTER_VERSION)/bin/cache/dart-sdk/bin/dart

MODULES := sesori_plugin_interface sesori_plugin_opencode sesori_plugin_codex app

.PHONY: codegen pub-get test analyze

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

TOOL_VERSIONS := $(shell git rev-parse --show-toplevel)/.tool-versions
FLUTTER_VERSION := $(shell grep '^flutter' $(TOOL_VERSIONS) | awk '{print $$2}')
DART := $(HOME)/.asdf/installs/flutter/$(FLUTTER_VERSION)/bin/cache/dart-sdk/bin/dart
FLUTTER := $(HOME)/.asdf/installs/flutter/$(FLUTTER_VERSION)/bin/flutter

# Dependency order: module_auth -> module_core -> app
MODULES := module_auth module_core app

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
			if [ "$$mod" = "app" ]; then \
				(cd $$mod && $(FLUTTER) test) || exit 1; \
			else \
				(cd $$mod && $(DART) test) || exit 1; \
			fi; \
		fi; \
	done

analyze:
	@for mod in $(MODULES); do \
		echo "=== analyze: $$mod ==="; \
		(cd $$mod && $(DART) analyze --fatal-infos) || exit 1; \
	done

TOOL_VERSIONS := $(shell git rev-parse --show-toplevel)/.tool-versions
FLUTTER_VERSION := $(shell grep '^flutter' $(TOOL_VERSIONS) | awk '{print $$2}')
DART := $(HOME)/.asdf/installs/flutter/$(FLUTTER_VERSION)/bin/cache/dart-sdk/bin/dart

# Standalone packages — each has its own pubspec.lock (NOT a workspace).
# Order matters: sesori_shared is consumed by both bridge and mobile workspaces.
MODULES := sesori_shared no_slop_linter

# Modules with active build_runner generators (no_slop_linter has no generators).
CODEGEN_MODULES := sesori_shared

.PHONY: codegen pub-get test analyze

pub-get:
	@for mod in $(MODULES); do \
		echo "=== pub-get: $$mod ==="; \
		(cd $$mod && $(DART) pub get) || exit 1; \
	done

codegen:
	@for mod in $(CODEGEN_MODULES); do \
		echo "=== codegen: $$mod ==="; \
		(cd $$mod && $(DART) run build_runner build --delete-conflicting-outputs) || exit 1; \
	done

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

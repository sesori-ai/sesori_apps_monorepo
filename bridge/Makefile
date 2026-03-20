DART_VERSION := $(shell grep '^dart' .tool-versions | awk '{print $$2}')
DART := $(HOME)/.asdf/installs/dart/$(DART_VERSION)/bin/dart

MODULES := sesori_plugin_interface sesori_plugin_opencode app

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

TOOL_VERSIONS := $(shell git rev-parse --show-toplevel)/.tool-versions
FLUTTER_VERSION := $(shell grep '^flutter' $(TOOL_VERSIONS) | awk '{print $$2}')
DART := $(HOME)/.asdf/installs/flutter/$(FLUTTER_VERSION)/bin/cache/dart-sdk/bin/dart
FLUTTER := $(HOME)/.asdf/installs/flutter/$(FLUTTER_VERSION)/bin/flutter

# Pin FLUTTER_ROOT to the version-locked SDK so the bundled `dart` resolves the
# right Flutter even when the shell exports a stale FLUTTER_ROOT (e.g. asdf global).
export FLUTTER_ROOT := $(HOME)/.asdf/installs/flutter/$(FLUTTER_VERSION)

# Dependency order: module_auth -> module_core -> module_zyra -> app
MODULES := module_auth module_core module_zyra app

.PHONY: codegen pub-get test analyze generate-assets generate-tokens

codegen:
	@for mod in $(MODULES); do \
		echo "=== codegen: $$mod ==="; \
		(cd $$mod && $(DART) run build_runner build) || exit 1; \
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

generate-assets:
	(cd module_zyra && $(DART) run scripts/generate_icon_font_dart.dart --font-dir assets/fonts/TablerIcons --output lib/icons/tabler_icons.g.dart --font-package theme_zyra --family-map "tabler-icons.ttf:TablerOutline:TablerOutline" --family-map "tabler-icons-filled.ttf:TablerFilled:TablerFilled")
	(cd module_zyra && $(DART) run scripts/generate_icon_font_dart.dart --font-dir assets/fonts/VESPRIcons --output lib/icons/vespr_icons.g.dart --font-package theme_zyra --family-map "VESPRIcons-Light.ttf:VESPRLight:VESPRLight" --family-map "VESPRIcons-Regular.ttf:VESPRRegular:VESPRRegular" --family-map "VESPRIcons-Solid.ttf:VESPRSolid:VESPRSolid")

generate-tokens:
	(cd module_zyra && $(DART) run scripts/figma_tokens/sync_figma_tokens.dart generate)

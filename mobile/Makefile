TOOL_VERSIONS := $(shell git rev-parse --show-toplevel)/.tool-versions
FLUTTER_VERSION := $(shell grep '^flutter' $(TOOL_VERSIONS) | awk '{print $$2}')
DART := $(HOME)/.asdf/installs/flutter/$(FLUTTER_VERSION)/bin/cache/dart-sdk/bin/dart
FLUTTER := $(HOME)/.asdf/installs/flutter/$(FLUTTER_VERSION)/bin/flutter

# Dependency order: module_auth -> module_core -> module_zyra -> app
MODULES := module_auth module_core module_zyra app

.PHONY: codegen pub-get test analyze generate-assets generate-tokens

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

generate-assets:
	(cd module_zyra && $(DART) run scripts/generate_icon_font_dart.dart --font-dir assets/fonts/FontAwesome6Pro --output lib/icons/fa6_pro_icons.g.dart --family-map "FA6Pro-Thin-100.otf:FA6Thin:FA6Thin" --family-map "FA6Pro-Light-300.otf:FA6Light:FA6Light" --family-map "FA6Pro-Regular-400.otf:FA6Regular:FA6Regular" --family-map "FA6Pro-Solid-900.otf:FA6Solid:FA6Solid")
	(cd module_zyra && $(DART) run scripts/generate_icon_font_dart.dart --font-dir assets/fonts/VESPRIcons --output lib/icons/vespr_icons.g.dart --family-map "VESPRIcons-Light.ttf:VESPRLight:VESPRLight" --family-map "VESPRIcons-Regular.ttf:VESPRRegular:VESPRRegular" --family-map "VESPRIcons-Solid.ttf:VESPRSolid:VESPRSolid")

generate-tokens:
	(cd module_zyra && $(DART) run scripts/figma_tokens/sync_figma_tokens.dart generate)

TOOL_VERSIONS := $(shell git rev-parse --show-toplevel)/.tool-versions
FLUTTER_VERSION := $(shell grep '^flutter' $(TOOL_VERSIONS) | awk '{print $$2}')
DART := $(HOME)/.asdf/installs/flutter/$(FLUTTER_VERSION)/bin/cache/dart-sdk/bin/dart
FLUTTER := $(HOME)/.asdf/installs/flutter/$(FLUTTER_VERSION)/bin/flutter

# Pin FLUTTER_ROOT to the version-locked SDK so the bundled `dart` resolves the
# right Flutter even when the shell exports a stale FLUTTER_ROOT (e.g. asdf global).
export FLUTTER_ROOT := $(HOME)/.asdf/installs/flutter/$(FLUTTER_VERSION)

.PHONY: pub-get manifest manifest-check inspector-tokens inspector-tokens-check analyze test build check

pub-get:
	(cd .. && $(DART) pub get)

manifest: pub-get
	$(DART) run tool/generate_manifest.dart

manifest-check: pub-get
	$(DART) run tool/generate_manifest.dart --check

inspector-tokens: pub-get
	$(DART) run tool/generate_inspector_tokens.dart

inspector-tokens-check: pub-get
	$(DART) run tool/generate_inspector_tokens.dart --check

analyze: pub-get
	$(DART) analyze --fatal-infos

test: pub-get
	$(FLUTTER) test

build: pub-get
	$(FLUTTER) build web --release

check: manifest-check inspector-tokens-check analyze test build

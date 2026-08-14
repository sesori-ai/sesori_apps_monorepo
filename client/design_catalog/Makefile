TOOL_VERSIONS := $(shell git rev-parse --show-toplevel)/.tool-versions
FLUTTER_VERSION := $(shell grep '^flutter' $(TOOL_VERSIONS) | awk '{print $$2}')
DART := $(HOME)/.asdf/installs/flutter/$(FLUTTER_VERSION)/bin/cache/dart-sdk/bin/dart
FLUTTER := $(HOME)/.asdf/installs/flutter/$(FLUTTER_VERSION)/bin/flutter

# Pin FLUTTER_ROOT to the version-locked SDK so the bundled `dart` resolves the
# right Flutter even when the shell exports a stale FLUTTER_ROOT (e.g. asdf global).
export FLUTTER_ROOT := $(HOME)/.asdf/installs/flutter/$(FLUTTER_VERSION)

.PHONY: pub-get manifest manifest-check analyze test build check

pub-get:
	(cd .. && $(DART) pub get)

manifest:
	$(DART) run tool/generate_manifest.dart

manifest-check:
	$(DART) run tool/generate_manifest.dart --check

analyze:
	$(DART) analyze --fatal-infos

test:
	$(FLUTTER) test

build:
	$(FLUTTER) build web --release

check: pub-get manifest-check analyze test build

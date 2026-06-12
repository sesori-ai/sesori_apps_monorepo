# Using direct path instead of `asdf exec dart` — asdf exec doesn't reliably pick up
# the version from .tool-versions and has a race condition when flutter plugin is also active.
DART_VERSION := $(shell grep '^dart' .tool-versions | awk '{print $$2}')
DART := $(HOME)/.asdf/installs/dart/$(DART_VERSION)/bin/dart

.PHONY: get test build publish

get:
	$(DART) pub get

test:
	$(DART) test

build:
	$(DART) run build_runner build --delete-conflicting-outputs

publish:
	$(DART) pub publish

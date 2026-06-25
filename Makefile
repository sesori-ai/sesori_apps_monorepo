TOOL_VERSIONS := $(shell git rev-parse --show-toplevel)/.tool-versions
FLUTTER_VERSION := $(shell grep '^flutter' $(TOOL_VERSIONS) | awk '{print $$2}')
DART ?= $(HOME)/.asdf/installs/flutter/$(FLUTTER_VERSION)/bin/cache/dart-sdk/bin/dart

.PHONY: pub-get bump-version bump-version-check

DART_WORKSPACES := shared bridge client

pub-get:
	@for dir in $(DART_WORKSPACES); do \
		printf '=== pub-get: %s ===\n' "$$dir"; \
		$(MAKE) --no-print-directory -C "$$dir" pub-get || exit 1; \
	done

define run_sync_versions
	@set -eu; \
	if [ -n "$(TYPE)" ] && [ -n "$(VERSION)" ]; then \
		printf '%s\n' 'Error: provide exactly one of TYPE or VERSION' >&2; \
		exit 1; \
	fi; \
	if [ -z "$(TYPE)" ] && [ -z "$(VERSION)" ]; then \
		printf '%s\n' 'Error: provide TYPE=patch|minor|major or VERSION=X.Y.Z' >&2; \
		exit 1; \
	fi; \
	args=''; \
	if [ -n "$(TYPE)" ]; then \
		args="$$args --type $(TYPE)"; \
	fi; \
	if [ -n "$(VERSION)" ]; then \
		args="$$args --version $(VERSION)"; \
	fi; \
	$(DART) tool/sync_versions.dart $(1) $$args
endef

bump-version-check:
	$(call run_sync_versions,--dry-run)

# Bump the version of the bridge and client (mobile) apps
#
# Two options to use it 
# a) make bump-version TYPE=patch|minor|major 
# b) make bump-version VERSION=x.y.z
bump-version:
	$(call run_sync_versions,)

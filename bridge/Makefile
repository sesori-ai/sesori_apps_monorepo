TOOL_VERSIONS := $(shell git rev-parse --show-toplevel)/.tool-versions
FLUTTER_VERSION := $(shell grep '^flutter' $(TOOL_VERSIONS) | awk '{print $$2}')
DART := $(HOME)/.asdf/installs/flutter/$(FLUTTER_VERSION)/bin/cache/dart-sdk/bin/dart

MODULES := sesori_plugin_interface sesori_plugin_runtime sesori_plugin_opencode sesori_plugin_codex app

.PHONY: codegen opencode-codegen pub-get test analyze

# Regenerates the OpenCode v2 REST client, model classes, and SSE event
# sealed-class hierarchy. OPT-IN: not a dependency of the regular `codegen`
# target, because the OpenAPI spec is maintained in a sibling repo
# (https://github.com/anomalyco/opencode) that may not be present on every
# developer's machine. Run explicitly when you want to refresh the v2
# generated code:
#
#   # Fetch a specific tag (the ref is resolved to a commit SHA via
#   # git ls-remote and recorded in every generated file header):
#   make opencode-codegen OPENCODE_TAG=v1.16.2
#
#   # Fetch the latest from a branch:
#   make opencode-codegen OPENCODE_BRANCH=dev
#
#   # Fetch a specific commit SHA (must be a 40-char hex SHA):
#   make opencode-codegen OPENCODE_COMMIT=76c631d1...
#
#   # Use a local openapi.json (no upstream ref recorded):
#   make opencode-codegen OPENCODE_SPEC=/path/to/openapi.json
#
# Exactly one of OPENCODE_TAG, OPENCODE_BRANCH, OPENCODE_COMMIT, or
# OPENCODE_SPEC is required. There is no default. A relative OPENCODE_SPEC
# path is resolved against this directory (bridge/) before the generator
# runs from sesori_plugin_opencode/.
#
# Generator arguments are accumulated as shell positional parameters
# (`set -- "$$@" ...`) rather than a flat string: embedding quotes in a
# string variable does NOT survive unquoted expansion (the quotes become
# literal characters and spaces still word-split), so paths with spaces
# would break.
#
# Reads `tool/opencode_events_v1.json` (hand-curated v1 SSE event manifest)
# and the OpenAPI spec.
opencode-codegen:
	@count=0; \
	set --; \
	if [ -n "$(OPENCODE_TAG)" ]; then set -- "$$@" --tag "$(OPENCODE_TAG)"; count=$$((count+1)); fi; \
	if [ -n "$(OPENCODE_BRANCH)" ]; then set -- "$$@" --branch "$(OPENCODE_BRANCH)"; count=$$((count+1)); fi; \
	if [ -n "$(OPENCODE_COMMIT)" ]; then set -- "$$@" --commit "$(OPENCODE_COMMIT)"; count=$$((count+1)); fi; \
	if [ -n "$(OPENCODE_SPEC)" ]; then \
		case "$(OPENCODE_SPEC)" in \
			/*) spec_path="$(OPENCODE_SPEC)";; \
			*) spec_path="$$PWD/$(OPENCODE_SPEC)";; \
		esac; \
		set -- "$$@" --local "$$spec_path"; count=$$((count+1)); \
	fi; \
	if [ $$count -eq 0 ]; then \
		echo "error: one of OPENCODE_TAG, OPENCODE_BRANCH, OPENCODE_COMMIT, or OPENCODE_SPEC is required."; \
		echo "  examples:"; \
		echo "    make opencode-codegen OPENCODE_TAG=v1.16.2"; \
		echo "    make opencode-codegen OPENCODE_BRANCH=dev"; \
		echo "    make opencode-codegen OPENCODE_COMMIT=76c631d1..."; \
		echo "    make opencode-codegen OPENCODE_SPEC=/path/to/openapi.json"; \
		exit 1; \
	fi; \
	if [ $$count -gt 1 ]; then \
		echo "error: OPENCODE_TAG, OPENCODE_BRANCH, OPENCODE_COMMIT, and OPENCODE_SPEC are mutually exclusive."; \
		exit 1; \
	fi; \
	(cd sesori_plugin_opencode && $(DART) run tool/generate_opencode_client.dart "$$@") && \
	(cd sesori_plugin_opencode && $(DART) run tool/generate_sse_events.dart)

codegen:
	@for mod in $(MODULES); do \
		if grep -q build_runner $$mod/pubspec.yaml; then \
			echo "=== codegen: $$mod ==="; \
			(cd $$mod && $(DART) run build_runner build --delete-conflicting-outputs); \
		else \
			echo "=== codegen: $$mod (skipped: no build_runner dependency) ==="; \
		fi; \
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

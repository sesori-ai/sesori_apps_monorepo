# Using direct path instead of `asdf exec dart` — asdf exec doesn't reliably pick up
# the version from .tool-versions and has a race condition when flutter plugin is also active.
DART_VERSION := $(shell grep '^dart' ../.tool-versions | awk '{print $$2}')
DART := $(HOME)/.asdf/installs/dart/$(DART_VERSION)/bin/dart
BUILD_DIR := dist
HOST_OS_RAW := $(shell uname -s)
HOST_ARCH_RAW := $(shell uname -m)
HOST_OS := $(if $(filter Darwin,$(HOST_OS_RAW)),macos,$(if $(filter Linux,$(HOST_OS_RAW)),linux,$(HOST_OS_RAW)))
HOST_ARCH := $(if $(filter x86_64,$(HOST_ARCH_RAW)),x64,$(if $(filter aarch64,$(HOST_ARCH_RAW)),arm64,$(HOST_ARCH_RAW)))

# dart build cli output structure: <output>/bundle/bin/<exe> + <output>/bundle/lib/<libs>
BUNDLE_DIR := build/cli
HOST_BINARY := $(BUILD_DIR)/bridge-$(HOST_OS)-$(HOST_ARCH)

.PHONY: build build-host run test analyze clean

# Note: cross-compilation (build-linux) was removed because sqlite3 v3.x uses
# Dart build hooks which require native compilation on the target platform.
# Cross-platform builds must happen in CI via a platform matrix (build natively
# on each OS/arch runner).
build: build-host

build-host: | $(BUILD_DIR)
	${DART} build cli -o $(BUNDLE_DIR)
	cp $(BUNDLE_DIR)/bundle/bin/bridge $(HOST_BINARY)
	@echo "Built: $(HOST_BINARY)"
	@echo "Bundle (with native libs): $(BUNDLE_DIR)/bundle/"

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

run:
	${DART} run bin/bridge.dart

test:
	${DART} test

analyze:
	${DART} analyze

clean:
	rm -rf $(BUILD_DIR) $(BUNDLE_DIR) .dart_tool/

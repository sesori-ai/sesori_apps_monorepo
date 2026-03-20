# Using direct path instead of `asdf exec dart` — asdf exec doesn't reliably pick up
# the version from .tool-versions and has a race condition when flutter plugin is also active.
DART_VERSION := $(shell grep '^dart' .tool-versions | awk '{print $$2}')
DART := $(HOME)/.asdf/installs/dart/$(DART_VERSION)/bin/dart
BUILD_DIR := dist
HOST_OS_RAW := $(shell uname -s)
HOST_ARCH_RAW := $(shell uname -m)
HOST_OS := $(if $(filter Darwin,$(HOST_OS_RAW)),macos,$(if $(filter Linux,$(HOST_OS_RAW)),linux,$(HOST_OS_RAW)))
HOST_ARCH := $(if $(filter x86_64,$(HOST_ARCH_RAW)),x64,$(if $(filter aarch64,$(HOST_ARCH_RAW)),arm64,$(HOST_ARCH_RAW)))
HOST_BUILD := $(BUILD_DIR)/bridge-$(HOST_OS)-$(HOST_ARCH)
LINUX_CROSS_ARCHES := $(filter-out $(if $(filter linux,$(HOST_OS)),$(HOST_ARCH),),arm arm64 riscv64 x64)
LINUX_CROSS_BUILDS := $(foreach arch,$(LINUX_CROSS_ARCHES),$(BUILD_DIR)/bridge-linux-$(arch))

.PHONY: build build-host build-linux run test analyze clean

build: build-host build-linux

build-host: $(HOST_BUILD)

build-linux: $(LINUX_CROSS_BUILDS)

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

$(HOST_BUILD): | $(BUILD_DIR)
	${DART} compile exe bin/bridge.dart -o $@

$(BUILD_DIR)/bridge-linux-%: | $(BUILD_DIR)
	${DART} compile exe bin/bridge.dart -o $@ --target-os=linux --target-arch=$*

run:
	${DART} run bin/bridge.dart

test:
	${DART} test

analyze:
	${DART} analyze

clean:
	rm -rf $(BUILD_DIR) .dart_tool/

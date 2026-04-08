#!/usr/bin/env sh

set -eu

cd "$(dirname "$0")/.."

flutter test --no-pub test/core/theme/sesori_theme_test.dart

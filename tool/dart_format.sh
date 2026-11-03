#!/usr/bin/env bash
# Formats the tracked, hand-written Dart files under the given directories.
# With --check it changes nothing, lists the files that need formatting and
# fails; CI runs it that way. Generated files are excluded here and nowhere
# else, so CI and local runs agree.
#
# Run `dart pub get` in each workspace first: the formatter reads every
# package's language version from its package config.
#
#   tool/dart_format.sh bridge                  # reformat the bridge
#   tool/dart_format.sh --check client shared   # check, as CI does
set -euo pipefail

check=false
options=(--output=write)
if [ "${1:-}" = --check ]; then
  check=true
  options=(--output=none --set-exit-if-changed)
  shift
fi
if [ $# -eq 0 ]; then
  echo "usage: $0 [--check] <directory>..." >&2
  exit 64
fi

# build_runner (*.g.dart, *.freezed.dart), injectable (*.config.dart),
# drift_dev (*.steps.dart and the test schemas under generated/) and the
# FlutterFire CLI (firebase_options.dart).
generated='\.(g|freezed|config|steps)\.dart$|/generated/|(^|/)firebase_options\.dart$'

files=()
while IFS= read -r -d '' file; do
  if [[ $file == *.dart && ! $file =~ $generated ]]; then
    files+=("$file")
  fi
done < <(git ls-files -z -- "$@")

if [ ${#files[@]} -eq 0 ]; then
  echo "No Dart files under: $*" >&2
  exit 1
fi

if ! dart format "${options[@]}" "${files[@]}"; then
  if [ "$check" = true ]; then
    echo "The files above need formatting. Fix them with: tool/dart_format.sh $*" >&2
  fi
  exit 1
fi

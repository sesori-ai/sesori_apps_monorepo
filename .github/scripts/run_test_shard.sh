#!/usr/bin/env bash
# Runs one shard of the current package's test files.
#
# Usage: run_test_shard.sh <dart|flutter> <index>/<count> [test args...]
#   run_test_shard.sh flutter 2/2 -j 4
#
# Shards by file, not with `--total-shards`: that option splits individual
# tests, so every shard would still compile and load every test file.
set -euo pipefail

runner=$1
index=${2%/*}
count=${2#*/}
shift 2

files=()
while IFS= read -r file; do
  files+=("$file")
done < <(find test -name '*_test.dart' | sort | awk -v n="$count" -v i="$index" '(NR - 1) % n == i - 1')
if [ "${#files[@]}" -eq 0 ]; then
  echo "No test files in shard $index/$count."
  exit 0
fi
"$runner" test "$@" "${files[@]}"

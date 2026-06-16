// Dependency-free tests for release_notes_resolver.dart.
//
// Run with: dart tool/release_notes_resolver_test.dart
// (No pub get / package:test required — matches the generator's standalone,
// deterministic contract.) Exits non-zero if any case fails.

import 'dart:io';

import 'release_notes_resolver.dart';

void main() {
  var failures = 0;

  void check({required String name, required bool passed}) {
    if (passed) {
      stdout.writeln('PASS: $name');
    } else {
      failures++;
      stdout.writeln('FAIL: $name');
    }
  }

  // Latest-release case: pick the highest stable below the target.
  check(
    name: 'latest picks highest below target',
    passed: selectPreviousStableTag(
          candidateTags: ['v1.1.0', 'v1.0.9', 'v1.0.8'],
          version: '1.2.0',
        ) ==
        'v1.1.0',
  );

  // Backfill: a newer stable release than the target exists — it must NOT be
  // chosen as the base (this is the bug the strictly-below rule fixes).
  check(
    name: 'backfill skips newer release than target',
    passed: selectPreviousStableTag(
          candidateTags: ['v1.2.0', 'v1.1.0', 'v1.0.9'],
          version: '1.1.0',
        ) ==
        'v1.0.9',
  );

  // The exact target tag is never selected as its own previous.
  check(
    name: 'excludes the exact target tag',
    passed: selectPreviousStableTag(
          candidateTags: ['v1.2.0', 'v1.1.0'],
          version: '1.2.0',
        ) ==
        'v1.1.0',
  );

  // A prerelease suffix on the target version is ignored for comparison.
  check(
    name: 'target prerelease suffix is ignored',
    passed: selectPreviousStableTag(
          candidateTags: ['v1.1.0', 'v1.0.9'],
          version: '1.2.0-internal.5',
        ) ==
        'v1.1.0',
  );

  // Prerelease/non-stable candidate tags are never treated as stable.
  check(
    name: 'skips non-stable candidate tags',
    passed: selectPreviousStableTag(
          candidateTags: ['v1.1.0-internal.3', 'v1.0.9'],
          version: '1.2.0',
        ) ==
        'v1.0.9',
  );

  // Ordering is numeric, not lexicographic (v1.10.0 > v1.9.0).
  check(
    name: 'numeric semver ordering',
    passed: selectPreviousStableTag(
          candidateTags: ['v1.9.0', 'v1.10.0'],
          version: '2.0.0',
        ) ==
        'v1.10.0',
  );

  // No candidate strictly below the target -> null (lets caller fall back).
  check(
    name: 'no candidate below target returns null',
    passed: selectPreviousStableTag(
          candidateTags: ['v2.0.0', 'v2.1.0'],
          version: '1.0.0',
        ) ==
        null,
  );

  // Empty candidate list -> null.
  check(
    name: 'empty candidate list returns null',
    passed: selectPreviousStableTag(candidateTags: [], version: '1.2.0') == null,
  );

  // parseStableTag rejects prerelease and accepts plain stable tags.
  check(name: 'parseStableTag rejects prerelease', passed: parseStableTag(tag: 'v1.2.0-internal.1') == null);
  check(name: 'parseStableTag rejects garbage', passed: parseStableTag(tag: 'release-1') == null);
  check(name: 'parseStableTag accepts stable', passed: parseStableTag(tag: 'v1.2.0') != null);

  if (failures > 0) {
    stdout.writeln('\n$failures test(s) failed');
    exit(1);
  }
  stdout.writeln('\nAll release_notes_resolver tests passed');
}

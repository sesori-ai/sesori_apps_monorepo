// Pure tag/semver selection logic for resolving the previous stable release
// tag, split out from generate_release_notes.dart so it can be unit-tested
// without any GitHub API access.
//
// Kept dependency-free (dart:core only) and side-effect-free, consistent with
// the generator's "deterministic, no pub get required" contract. Run the
// accompanying tests with `dart tool/release_notes_resolver_test.dart`.

final RegExp _stableTagPattern = RegExp(r'^v(\d+)\.(\d+)\.(\d+)$');

/// Parses a plain `vX.Y.Z` tag into `[major, minor, patch]`.
///
/// Returns null for anything carrying a prerelease suffix (e.g.
/// `v1.2.0-internal.3`) or a non-standard shape, so prerelease tags can never
/// be treated as stable.
List<int>? parseStableTag({required String tag}) {
  final match = _stableTagPattern.firstMatch(tag);
  if (match == null) {
    return null;
  }
  return [
    int.parse(match.group(1)!),
    int.parse(match.group(2)!),
    int.parse(match.group(3)!),
  ];
}

/// Compares two `[major, minor, patch]` triples numerically.
///
/// Returns a negative number when [a] < [b], zero when equal, positive when
/// [a] > [b]. Numeric (not lexicographic) so `v1.10.0` sorts above `v1.9.0`.
int compareSemver({required List<int> a, required List<int> b}) {
  for (var i = 0; i < 3; i++) {
    final diff = a[i].compareTo(b[i]);
    if (diff != 0) {
      return diff;
    }
  }
  return 0;
}

/// Picks the highest plain `vX.Y.Z` tag from [candidateTags] that is strictly
/// below [version] (any prerelease suffix on [version] is ignored). Returns
/// null when no candidate qualifies.
///
/// "Strictly below the target" is what makes backfills correct: when
/// regenerating notes for an older release after a newer one has shipped, the
/// previous-stable base must be the release *below* the target, never the newer
/// release. Callers are expected to pre-filter the candidate list to the right
/// source (published non-draft/non-prerelease releases first, plain git tags as
/// a fallback) — this function only enforces the stable + strictly-below rule.
String? selectPreviousStableTag({
  required Iterable<String> candidateTags,
  required String version,
}) {
  // Strip any prerelease suffix so the target is always compared as vX.Y.Z.
  final baseVersion = version.split('-').first;
  final excludedTag = 'v$baseVersion';
  final targetParts = parseStableTag(tag: excludedTag);

  String? best;
  List<int>? bestParts;
  for (final tag in candidateTags) {
    if (tag == excludedTag) {
      continue;
    }
    final parts = parseStableTag(tag: tag);
    if (parts == null) {
      continue;
    }
    // Only consider stable versions strictly below the one being released.
    if (targetParts != null && compareSemver(a: parts, b: targetParts) >= 0) {
      continue;
    }
    if (bestParts == null || compareSemver(a: parts, b: bestParts) > 0) {
      best = tag;
      bestParts = parts;
    }
  }
  return best;
}

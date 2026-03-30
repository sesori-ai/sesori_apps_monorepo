/// Sanitizes an arbitrary string into a git-safe branch name.
///
/// Applies the following transformations in order:
/// 1. Lowercase the input
/// 2. Replace spaces, underscores, slashes with hyphens
/// 3. Strip trailing dots and `.lock` suffix (in that order)
/// 4. Reject if contains `..` anywhere
/// 5. Strip all non-ASCII and non-alphanumeric characters (except hyphens)
/// 6. Collapse consecutive hyphens into single hyphens
/// 7. Strip leading and trailing hyphens
/// 8. Truncate to max 60 chars (at a hyphen boundary if possible)
/// 9. Return `null` if result is empty after sanitization
///
/// Examples:
/// - `"Fix Login Bug"` → `"fix-login-bug"`
/// - `"🚀 Deploy v2"` → `"deploy-v2"`
/// - `"session.lock"` → `"session"`
/// - `""` → `null`
/// - `"..."` → `null`
String? sanitizeBranchName({required String raw}) {
  if (raw.isEmpty) {
    return null;
  }

  // Step 1: Lowercase
  var result = raw.toLowerCase();

  // Step 2: Replace spaces, underscores, slashes with hyphens
  result = result.replaceAll(RegExp('[ _/]'), '-');

  // Step 3: Strip trailing dots and `.lock` suffix
  // First strip trailing dots
  result = result.replaceAll(RegExp(r'\.+$'), '');
  // Then strip trailing `.lock` suffix
  if (result.endsWith('.lock')) {
    result = result.substring(0, result.length - 5);
  }

  // Step 4: Reject if contains `..` anywhere
  if (result.contains('..')) {
    return null;
  }

  // Step 5: Strip all non-ASCII and non-alphanumeric characters (except hyphens)
  result = result.replaceAll(RegExp(r'[^a-z0-9\-]'), '');

  // Step 6: Collapse consecutive hyphens into single hyphens
  result = result.replaceAll(RegExp('-+'), '-');

  // Step 7: Strip leading and trailing hyphens
  result = result.replaceAll(RegExp(r'^-+|-+$'), '');

  // Step 8: Truncate to max 60 chars (at a hyphen boundary if possible)
  if (result.length > 60) {
    result = result.substring(0, 60);
    // Try to truncate at a hyphen boundary
    final lastHyphenIndex = result.lastIndexOf('-');
    if (lastHyphenIndex > 0) {
      result = result.substring(0, lastHyphenIndex);
    }
  }

  // Step 9: Return null if result is empty
  if (result.isEmpty) {
    return null;
  }

  return result;
}

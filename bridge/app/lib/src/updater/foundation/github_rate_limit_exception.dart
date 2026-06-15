/// Thrown when the GitHub releases API rejects a request because the caller has
/// exhausted its rate-limit budget (HTTP 429, or HTTP 403 with
/// `x-ratelimit-remaining: 0`).
///
/// Unauthenticated requests share a budget of 60 requests/hour per source IP,
/// so this is commonly hit from behind shared/NAT'd networks even when this
/// bridge itself only checks for updates a handful of times per day.
class GitHubRateLimitException implements Exception {
  /// When the rate-limit window resets, in local time, when the response
  /// advertised it via `x-ratelimit-reset` (epoch seconds) or `retry-after`.
  /// Null when the response carried no usable reset hint.
  final DateTime? resetAt;

  const GitHubRateLimitException({required this.resetAt});

  @override
  String toString() {
    final reset = resetAt;
    if (reset == null) {
      return 'GitHubRateLimitException: GitHub API rate limit reached';
    }
    return 'GitHubRateLimitException: GitHub API rate limit reached '
        '(resets at ${reset.toIso8601String()})';
  }
}

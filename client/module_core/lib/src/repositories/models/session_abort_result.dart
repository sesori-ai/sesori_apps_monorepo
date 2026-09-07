/// Client-domain interpretation of bridge descendant-stop coverage.
final class const SessionAbortResult({required final SessionAbortCoverage coverage});

/// Which descendant stops remain after the root abort request.
sealed class const SessionAbortCoverage();

/// The bridge handled every descendant; no client fanout remains.
final class const SessionAbortCoverageHandled() extends SessionAbortCoverage;

/// Exact descendants remain and take precedence over screen-state fallback.
final class const SessionAbortCoveragePartial({
  required final List<String> unhandledSessionIds,
}) extends SessionAbortCoverage;

/// The bridge cannot report exact coverage, so visible-child fallback remains.
final class const SessionAbortCoverageLegacy({
  required final List<String> handledSessionIds,
}) extends SessionAbortCoverage;

import "package:sesori_auth/sesori_auth.dart";

sealed class const SessionDiffSummaryResult();

/// The session's line totals across every changed file.
final class const SessionDiffSummaryAvailable({
  required final int additions,
  required final int deletions,
}) extends SessionDiffSummaryResult;

/// The bridge predates the summary request, so asking again cannot succeed.
final class const SessionDiffSummaryUnsupported() extends SessionDiffSummaryResult;

final class const SessionDiffSummaryFailure({required final ApiError error}) extends SessionDiffSummaryResult;

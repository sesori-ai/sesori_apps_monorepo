import "package:sesori_shared/sesori_shared.dart" show SessionBranchErrorCode;

/// Bridge-owned refusal of a session edit or fork, answered as a
/// `SessionBranchErrorResponse`.
class const SessionBranchRefusedException({
  required final SessionBranchErrorCode code,

  /// Written for the user and safe to show, or null when there is no such
  /// sentence and the client shows its own.
  required final String? message,

  /// The failure this refusal translates, when there is one.
  required final Object? cause,
  required final StackTrace? causeStackTrace,
}) implements Exception {
  @override
  String toString() {
    final causeDetail = cause == null ? "" : " (cause: ${cause.toString()})";
    return "SessionBranchRefusedException: ${code.name}$causeDetail";
  }
}

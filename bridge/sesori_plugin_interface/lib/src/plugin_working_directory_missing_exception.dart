import "plugin_session_unrestorable_exception.dart";

/// A session's recorded working directory no longer exists (for example a
/// deleted worktree), so no backend process can start in it.
///
/// This is a per-session failure, not a backend health problem: plugins throw
/// it instead of reporting a spawn failure. The user-facing [message] omits
/// the [path]; [toString] keeps it for local logs.
class const PluginWorkingDirectoryMissingException({
  required super.operation,
  required final String path,
  required super.cause,
}) extends PluginSessionUnrestorableException {
  this : super(message: "This session's folder no longer exists, so it cannot be continued.");

  @override
  String toString() {
    final causeDetail = cause == null ? "" : " (cause: ${cause.toString()})";
    return "PluginWorkingDirectoryMissingException: $operation failed: '$path' does not exist$causeDetail";
  }
}

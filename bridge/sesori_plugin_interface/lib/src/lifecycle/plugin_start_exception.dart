/// A plugin's `start()` could not produce a working instance.
///
/// Contract: before throwing this (or anything else), `start()` MUST release
/// everything it acquired — kill spawned processes, delete ownership records
/// it wrote, close sockets. The bridge holds its cross-instance startup mutex
/// until `start()` settles, so a throw that leaks resources would leak them
/// under the lock with no owner left to clean up.
class PluginStartException implements Exception {
  const PluginStartException(this.message, {required this.cause});

  /// Human-readable description of why the plugin could not start.
  final String message;

  /// The underlying error, when one exists.
  final Object? cause;

  @override
  String toString() {
    final causeDetail = cause == null ? "" : " (cause: $cause)";
    return "PluginStartException: $message$causeDetail";
  }
}

/// A plugin's `start()` was aborted through `PluginHost.startAborted`.
///
/// This is how an aborted start MUST settle: roll back everything acquired,
/// then throw this. The distinct type lets the bridge tell "aborted as
/// requested" (expected — the bridge asked for it) apart from "failed to
/// start" (an error worth surfacing loudly).
class PluginStartAbortedException extends PluginStartException {
  const PluginStartAbortedException() : super("Plugin start aborted by the bridge.", cause: null);

  @override
  String toString() => "PluginStartAbortedException: $message";
}

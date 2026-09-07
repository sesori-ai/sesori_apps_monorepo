/// Base failure for any plugin operation, regardless of transport.
///
/// Routers forward [statusCode] onto the relayed HTTP response when present
/// and fall back to 502 otherwise, so plugins that are not HTTP-backed
/// (CLI invocations, remote SDKs) can throw this directly without inventing
/// fake HTTP codes.
class PluginOperationException implements Exception {
  /// The operation that failed (an endpoint, a CLI invocation, an RPC name).
  final String operation;

  /// Upstream HTTP status when the failure has one; `null` otherwise.
  final int? statusCode;

  final String? message;
  // ignore: no_slop_linter/prefer_specific_type, caught errors are opaque
  final Object? cause;

  const new(
    this.operation, {
    this.statusCode,
    this.message,
    this.cause,
  });

  /// Failure meaning the target entity does not exist.
  ///
  /// Handlers use [isNotFound] for idempotent deletes, so non-HTTP plugins
  /// should signal missing entities through this constructor rather than a
  /// hand-rolled status code.
  const new notFound(this.operation, {this.message, this.cause}) : statusCode = 404;

  /// `true` when this failure means the target entity does not exist.
  bool get isNotFound => statusCode == 404;

  /// `true` when the backend could not be reached at all, so retrying the same
  /// call cannot succeed until the plugin becomes routable again.
  bool get isUnavailable => statusCode == 503;

  @override
  String toString() {
    final status = statusCode == null ? "" : " with status $statusCode";
    final detail = message == null ? "" : ": $message";
    final causeDetail = cause == null ? "" : " (cause: ${cause.toString()})";
    return "PluginOperationException: $operation failed$status$detail$causeDetail";
  }
}

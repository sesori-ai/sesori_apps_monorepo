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
  final Object? cause;

  const PluginOperationException(
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
  const PluginOperationException.notFound(this.operation, {this.message, this.cause}) : statusCode = 404;

  /// `true` when this failure means the target entity does not exist.
  bool get isNotFound => statusCode == 404;

  @override
  String toString() {
    final status = statusCode == null ? "" : " with status $statusCode";
    final detail = message == null ? "" : ": $message";
    return "PluginOperationException: $operation failed$status$detail";
  }
}
